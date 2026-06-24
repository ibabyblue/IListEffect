#if canImport(SwiftUI)
import SwiftUI
import ListEffectCore

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    /// 为滚动容器中的行施加位置型效果。基于 `.scrollTransition`，需放在每个 row 上。
    func listEffect(_ effect: PositionEffect) -> some View {
        scrollTransition { content, phase in
            let out = effect.resolve(position: CGFloat(phase.value))
            let axis = out.rotationAxis ?? .z
            let anchor = UnitPoint(x: (out.anchor ?? .center).x, y: (out.anchor ?? .center).y)
            // scrollTransition 闭包内 content 是 VisualEffect（无 .modifier、非 @ViewBuilder），
            // 且 2D/3D 旋转返回不同 opaque 类型无法合并，故 axis==.z 时统一走 rotation3DEffect
            // 传 axis=(0,0,1)：绕 Z 轴旋转，透视项不生效（透视仅对绕 x/y 轴、含平行屏幕分量的旋转产生汇聚），
            // 故与 .rotationEffect 数学等价。perspective 值此处无关紧要。
            // 变换顺序：offset → scale → rotation → opacity（与 brief 一致）。
            // axis 判断逻辑与 RotationModifier.body 相同，C2 的 entranceEffect 将复用 RotationModifier。
            return content
                .offset(x: out.translation.x, y: out.translation.y)
                .scaleEffect(out.scale, anchor: anchor)
                .rotation3DEffect(.radians(Double(out.rotation)),
                                  axis: (x: axis.x, y: axis.y, z: axis.z),
                                  anchor: anchor,
                                  perspective: 1)
                .opacity(out.alpha)
        }
    }
}

/// 复用的旋转修饰器。C2 的 entranceEffect（View 上下文，body 为 @ViewBuilder）
/// 直接 .modifier(RotationModifier(...)) 使用；axis==.z 时走轻量 .rotationEffect，否则 3D。
/// listEffect 因 scrollTransition 闭包返回 VisualEffect 且需单一返回类型，已用等价 rotation3DEffect 内联。
@available(iOS 17.0, macOS 14.0, *)
private struct RotationModifier: ViewModifier {
    let radians: CGFloat
    let axis: RotationAxis
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        if axis == .z {
            content.rotationEffect(.radians(Double(radians)), anchor: anchor)
        } else {
            content.rotation3DEffect(.radians(Double(radians)),
                                     axis: (x: axis.x, y: axis.y, z: axis.z),
                                     anchor: anchor,
                                     perspective: 1)
        }
    }
}

// MARK: - 入场效果（entrance）
//
// 设计：彻底解决 LazyVStack 下「部分 cell 不播入场、滚动割裂」。根因是旧实现用
// `.onAppear` 触发动画——而 LazyVStack 的 onAppear 在屏外缓冲区就触发，0.5s 动画
// 常在 cell 真正滚进可视区前就播完，于是滚到眼前已静止＝「没动画」；滚动速度不同
// 导致有的赶上有的没赶上。
//
// 新实现把「何时入场」从 onAppear 时机解耦到**真实滚动几何**：
//   - `.listEntrance()` 装在 ScrollView 上，提供命名坐标系 + 视口高度 + 跨 cell 的
//     `EntranceCoordinator`（记录已入场的 index，实现「只入场一次」latch）。
//   - 每个 row 用后台 GeometryReader 读自身在命名坐标系中的 frame，判定真正进入视口
//     的那一刻才触发一次定时滑入。首批（首屏可见）按到达顺序错峰；滚动进入的 delay=0。
//   - 已入场的 index 再次出现（回滑销毁重建）直接归位、不重播。
// 几何驱动＝确定性，不再依赖 onAppear 时机，故无割裂。
//
// 兼容：未装 `.listEntrance()` 时退回旧的 onAppear 一次性入场（无 latch，但不再回弹）。

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    /// 入场协调容器：装在 ScrollView 上，为内部 `.entranceEffect` 提供跨 cell 的
    /// 「只入场一次」latch 与真实可见性判定，消除 LazyVStack 滚动割裂。
    /// - Parameters:
    ///   - perRowDelay: 首批相邻行错峰延迟（秒）。
    ///   - delayRowCap: 首批参与错峰的行数上限，防止延迟爆炸。
    func listEntrance(perRowDelay: TimeInterval = 0.05,
                      delayRowCap: Int = 12) -> some View {
        modifier(ListEntranceContainerModifier(perRowDelay: perRowDelay, delayRowCap: delayRowCap))
    }

    /// 入场效果：cell 首次真正进入视口时，一次性滑入（progress 端点插值，无回弹）。
    /// - Parameters:
    ///   - index: 行号；既是首批错峰依据，也是「只入场一次」latch 的键。
    ///     强烈建议传入；nil 时退化为按实例触发、无跨重建 latch。
    ///   - perRowDelay/delayRowCap: 仅在未装 `.listEntrance()` 的回退路径生效；
    ///     装了容器时以容器参数为准。
    func entranceEffect(_ effect: EntranceEffect,
                        index: Int? = nil,
                        perRowDelay: TimeInterval = 0.05,
                        delayRowCap: Int = 12) -> some View {
        modifier(EntranceEffectModifier(effect: effect,
                                        index: index,
                                        fallbackPerRowDelay: perRowDelay,
                                        fallbackDelayRowCap: delayRowCap))
    }
}

/// 命名坐标系：row 用它把自身 frame 解析为「相对视口」的位置。
let entranceCoordinateSpace = "IListEffect.entrance.scroll"

/// 纯函数：row 在视口命名坐标系中的 frame 是否与视口相交（真正可见）。可单测。
func entranceRowIsVisible(rowMinY: CGFloat, rowMaxY: CGFloat, viewportHeight: CGFloat) -> Bool {
    guard viewportHeight > 0 else { return false }
    return rowMaxY > 0 && rowMinY < viewportHeight
}

/// 跨 cell 的入场协调器：latch 已入场 index（只入场一次）+ 首批错峰编排。
@available(iOS 17.0, macOS 14.0, *)
final class EntranceCoordinator: ObservableObject {
    let perRowDelay: TimeInterval
    let delayRowCap: Int
    private var entered = Set<Int>()
    private var acceptingInitialBatch = true
    private var initialOrder = 0

    init(perRowDelay: TimeInterval, delayRowCap: Int) {
        self.perRowDelay = perRowDelay
        self.delayRowCap = delayRowCap
    }

    func hasEntered(_ index: Int) -> Bool { entered.contains(index) }

    /// 登记一次入场。已入场返回 nil（调用方应直接归位、不动画）；
    /// 否则标记入场并返回错峰延迟：首批按到达顺序错峰，滚动进入的为 0。
    func registerEntrance(index: Int) -> TimeInterval? {
        if entered.contains(index) { return nil }
        entered.insert(index)
        guard acceptingInitialBatch else { return 0 }
        let delay = TimeInterval(min(initialOrder, delayRowCap)) * perRowDelay
        initialOrder += 1
        return delay
    }

    /// 首批窗口关闭后，新进入的 cell 不再错峰（delay=0）。
    func closeInitialBatch() { acceptingInitialBatch = false }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EntranceCoordinatorKey: EnvironmentKey {
    static let defaultValue: EntranceCoordinator? = nil
}
private struct EntranceViewportKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

@available(iOS 17.0, macOS 14.0, *)
extension EnvironmentValues {
    var entranceCoordinator: EntranceCoordinator? {
        get { self[EntranceCoordinatorKey.self] }
        set { self[EntranceCoordinatorKey.self] = newValue }
    }
    var entranceViewport: CGFloat {
        get { self[EntranceViewportKey.self] }
        set { self[EntranceViewportKey.self] = newValue }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ListEntranceContainerModifier: ViewModifier {
    @StateObject private var coordinator: EntranceCoordinator
    @State private var viewport: CGFloat = 0

    init(perRowDelay: TimeInterval, delayRowCap: Int) {
        _coordinator = StateObject(wrappedValue: EntranceCoordinator(perRowDelay: perRowDelay,
                                                                     delayRowCap: delayRowCap))
    }

    func body(content: Content) -> some View {
        content
            .coordinateSpace(.named(entranceCoordinateSpace))
            .environment(\.entranceCoordinator, coordinator)
            .environment(\.entranceViewport, viewport)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            viewport = geo.size.height
                            // 首批窗口：留足首屏错峰时间后关闭，之后滚动进入者 delay=0。
                            let window = max(0.2, coordinator.perRowDelay * TimeInterval(coordinator.delayRowCap))
                            DispatchQueue.main.asyncAfter(deadline: .now() + window) {
                                coordinator.closeInitialBatch()
                            }
                        }
                        .onChange(of: geo.size.height) { _, h in viewport = h }
                }
            )
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EntranceEffectModifier: ViewModifier {
    let effect: EntranceEffect
    let index: Int?
    let fallbackPerRowDelay: TimeInterval
    let fallbackDelayRowCap: Int

    @Environment(\.entranceCoordinator) private var coordinator
    @Environment(\.entranceViewport) private var viewport
    @State private var appeared = false
    @State private var triggered = false

    func body(content: Content) -> some View {
        let initial = effect.resolve(progress: 0)
        let axis = initial.rotationAxis ?? .z
        let anchor = UnitPoint(x: (initial.anchor ?? .center).x, y: (initial.anchor ?? .center).y)
        // 已入场过的 index（回滑重建）直接按归位渲染，避免重建瞬间闪一帧滑出态。
        let alreadyEntered = index.flatMap { coordinator?.hasEntered($0) } ?? false
        let shown = appeared || alreadyEntered
        return content
            .offset(x: shown ? 0 : initial.translation.x,
                    y: shown ? 0 : initial.translation.y)
            .scaleEffect(shown ? 1 : initial.scale, anchor: anchor)
            .modifier(RotationModifier(radians: shown ? 0 : initial.rotation, axis: axis, anchor: anchor))
            .opacity(shown ? 1 : initial.alpha)
            .background(visibilityProbe)
            .onAppear {
                // 无容器：退回 onAppear 一次性入场（无 latch，但已无回弹）。
                if coordinator == nil { fallbackTrigger() }
            }
    }

    @ViewBuilder private var visibilityProbe: some View {
        if coordinator != nil {
            GeometryReader { geo in
                let f = geo.frame(in: .named(entranceCoordinateSpace))
                Color.clear
                    .onChange(of: entranceRowIsVisible(rowMinY: f.minY,
                                                       rowMaxY: f.maxY,
                                                       viewportHeight: viewport),
                              initial: true) { _, vis in
                        if vis { coordinatedTrigger() }
                    }
            }
        } else {
            Color.clear
        }
    }

    private func coordinatedTrigger() {
        guard !triggered else { return }
        guard let c = coordinator, let idx = index else {
            fallbackTrigger()   // 有容器但无 index：退化为按实例一次
            return
        }
        triggered = true
        if c.hasEntered(idx) {
            appeared = true     // 已入场过：直接归位，不重播
            return
        }
        let delay = c.registerEntrance(index: idx) ?? 0
        withAnimation(.easeOut(duration: effect.duration).delay(delay)) { appeared = true }
    }

    private func fallbackTrigger() {
        guard !triggered else { return }
        triggered = true
        let delay = index.map { TimeInterval(min(max(0, $0), fallbackDelayRowCap)) * fallbackPerRowDelay } ?? 0
        withAnimation(.easeOut(duration: effect.duration).delay(delay)) { appeared = true }
    }
}
#endif
