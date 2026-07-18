#if canImport(SwiftUI)
import SwiftUI
import ListEffectCore

@available(iOS 17.0, macOS 14.0, *)
/// Scroll-linked and entrance-effect conveniences for SwiftUI views.
public extension View {
    /// Applies a scroll-linked position effect to an item inside a scroll container.
    ///
    /// Apply this modifier to each row. The implementation uses `scrollTransition`
    /// to resolve the item's live viewport position.
    ///
    /// - Parameter effect: The position effect to apply.
    /// - Returns: A view that responds to its scroll-transition phase.
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

/// Applies either a two-dimensional or three-dimensional rotation.
@available(iOS 17.0, macOS 14.0, *)
private struct RotationModifier: ViewModifier {
    /// The rotation angle in radians.
    let radians: CGFloat
    /// The axis around which the content rotates.
    let axis: RotationAxis
    /// The normalized anchor used for the rotation.
    let anchor: UnitPoint

    /// Applies the appropriate rotation API for the configured axis.
    ///
    /// - Parameter content: The content supplied by SwiftUI.
    /// - Returns: The rotated content.
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
/// Entrance-effect conveniences for SwiftUI views.
public extension View {
    /// Installs entrance coordination and viewport measurement on a scroll container.
    ///
    /// Apply this modifier to the `ScrollView` that contains rows using
    /// ``entranceEffect(_:id:perRowDelay:delayRowCap:)`` or
    /// ``entranceEffect(_:index:perRowDelay:delayRowCap:)``.
    ///
    /// - Parameters:
    ///   - perRowDelay: The delay between adjacent rows in the initial batch, in seconds.
    ///   - delayRowCap: The maximum initial-batch position used to calculate delay.
    /// - Returns: A scroll container that coordinates one-shot row entrances.
    func listEntrance(perRowDelay: TimeInterval = 0.05,
                      delayRowCap: Int = 12) -> some View {
        modifier(ListEntranceContainerModifier(perRowDelay: perRowDelay, delayRowCap: delayRowCap))
    }

    /// Applies a one-shot entrance effect keyed by an optional row index.
    ///
    /// With ``listEntrance(perRowDelay:delayRowCap:)`` installed, the effect begins
    /// when the row actually intersects the viewport. Without the container, it
    /// falls back to a one-shot `onAppear` animation.
    ///
    /// - Parameters:
    ///   - effect: The entrance effect to apply.
    ///   - index: The row identity and fallback stagger position. Pass a value to
    ///     preserve one-shot behavior across lazy-view reconstruction.
    ///   - perRowDelay: The fallback delay between adjacent row indexes, in seconds.
    ///   - delayRowCap: The fallback maximum row index used to calculate delay.
    /// - Returns: A view that animates into its settled state once.
    func entranceEffect(_ effect: EntranceEffect,
                        index: Int? = nil,
                        perRowDelay: TimeInterval = 0.05,
                        delayRowCap: Int = 12) -> some View {
        modifier(EntranceEffectModifier(effect: effect,
                                        identity: index.map(AnyHashable.init),
                                        fallbackIndex: index,
                                        fallbackPerRowDelay: perRowDelay,
                                        fallbackDelayRowCap: delayRowCap))
    }

    /// Applies a one-shot entrance effect keyed by a stable business identity.
    ///
    /// - Parameters:
    ///   - effect: The entrance effect to apply.
    ///   - id: A stable identity that survives insertion, deletion, and reordering.
    ///   - perRowDelay: The fallback delay between adjacent rows, in seconds.
    ///   - delayRowCap: The fallback maximum row position used to calculate delay.
    /// - Returns: A view that animates only once for the supplied identity.
    func entranceEffect<ID: Hashable>(_ effect: EntranceEffect,
                                      id: ID,
                                      perRowDelay: TimeInterval = 0.05,
                                      delayRowCap: Int = 12) -> some View {
        modifier(EntranceEffectModifier(effect: effect,
                                        identity: AnyHashable(id),
                                        fallbackIndex: nil,
                                        fallbackPerRowDelay: perRowDelay,
                                        fallbackDelayRowCap: delayRowCap))
    }
}

/// The named coordinate space used to measure entrance rows relative to their viewport.
let entranceCoordinateSpace = "IListEffect.entrance.scroll"

/// Determines whether a row intersects the measured entrance viewport.
///
/// - Parameters:
///   - rowMinY: The row's minimum vertical coordinate in the entrance coordinate space.
///   - rowMaxY: The row's maximum vertical coordinate in the entrance coordinate space.
///   - viewportHeight: The measured viewport height.
/// - Returns: `true` when the row and viewport overlap.
func entranceRowIsVisible(rowMinY: CGFloat, rowMaxY: CGFloat, viewportHeight: CGFloat) -> Bool {
    guard viewportHeight > 0 else { return false }
    return rowMaxY > 0 && rowMinY < viewportHeight
}

/// Coordinates stable one-shot entrance identities and initial-batch staggering.
@available(iOS 17.0, macOS 14.0, *)
final class EntranceCoordinator: ObservableObject {
    /// The delay between adjacent rows in the initial batch, in seconds.
    let perRowDelay: TimeInterval
    /// The maximum initial-batch position used to calculate staggered delay.
    let delayRowCap: Int
    /// The stable identities that have completed entrance registration.
    private var entered = Set<AnyHashable>()
    /// A value indicating whether newly registered rows belong to the initial batch.
    private var acceptingInitialBatch = true
    /// The registration order of the next initial-batch row.
    private var initialOrder = 0

    /// Creates an entrance coordinator.
    ///
    /// - Parameters:
    ///   - perRowDelay: The delay between adjacent initial rows, in seconds.
    ///   - delayRowCap: The maximum position used to calculate delay.
    init(perRowDelay: TimeInterval, delayRowCap: Int) {
        self.perRowDelay = perRowDelay
        self.delayRowCap = delayRowCap
    }

    /// Returns whether an integer row identity has already entered.
    ///
    /// - Parameter index: The row identity to query.
    /// - Returns: `true` when the identity is already registered.
    func hasEntered(_ index: Int) -> Bool { hasEntered(id: index) }

    /// Returns whether a stable identity has already entered.
    ///
    /// - Parameter id: The stable identity to query.
    /// - Returns: `true` when the identity is already registered.
    func hasEntered<ID: Hashable>(id: ID) -> Bool { entered.contains(AnyHashable(id)) }

    /// Registers an integer row identity for entrance.
    ///
    /// - Parameter index: The row identity to register.
    /// - Returns: Its stagger delay, or `nil` when the identity was already registered.
    func registerEntrance(index: Int) -> TimeInterval? { registerEntrance(id: index) }

    /// Registers a stable identity for entrance.
    ///
    /// Initial-batch identities receive staggered delays. Identities registered
    /// after ``closeInitialBatch()`` receive zero delay.
    ///
    /// - Parameter id: The stable identity to register.
    /// - Returns: Its stagger delay, or `nil` when the identity was already registered.
    func registerEntrance<ID: Hashable>(id: ID) -> TimeInterval? {
        let key = AnyHashable(id)
        if entered.contains(key) { return nil }
        entered.insert(key)
        guard acceptingInitialBatch else { return 0 }
        let delay = TimeInterval(min(initialOrder, delayRowCap)) * perRowDelay
        initialOrder += 1
        return delay
    }

    /// Closes the initial-batch window so later rows receive zero delay.
    func closeInitialBatch() { acceptingInitialBatch = false }

    /// Clears all registered identities and starts a new initial batch.
    func resetEnteredState() {
        entered.removeAll()
        acceptingInitialBatch = true
        initialOrder = 0
    }
}

@available(iOS 17.0, macOS 14.0, *)
/// The environment key for an optional entrance coordinator.
private struct EntranceCoordinatorKey: EnvironmentKey {
    /// The absence of a coordinator outside a list entrance container.
    static let defaultValue: EntranceCoordinator? = nil
}
/// The environment key for the measured entrance viewport height.
private struct EntranceViewportKey: EnvironmentKey {
    /// The unmeasured viewport height.
    static let defaultValue: CGFloat = 0
}

@available(iOS 17.0, macOS 14.0, *)
/// Environment values used by coordinated entrance effects.
extension EnvironmentValues {
    /// The nearest entrance coordinator, if a list entrance container is installed.
    var entranceCoordinator: EntranceCoordinator? {
        get { self[EntranceCoordinatorKey.self] }
        set { self[EntranceCoordinatorKey.self] = newValue }
    }
    /// The measured height of the nearest entrance viewport.
    var entranceViewport: CGFloat {
        get { self[EntranceViewportKey.self] }
        set { self[EntranceViewportKey.self] = newValue }
    }
}

@available(iOS 17.0, macOS 14.0, *)
/// Installs entrance coordination, a named coordinate space, and viewport measurement.
private struct ListEntranceContainerModifier: ViewModifier {
    /// The coordinator shared with descendant entrance rows.
    @StateObject private var coordinator: EntranceCoordinator
    /// The current measured viewport height.
    @State private var viewport: CGFloat = 0

    /// Creates a coordinated list entrance container.
    ///
    /// - Parameters:
    ///   - perRowDelay: The delay between adjacent initial rows, in seconds.
    ///   - delayRowCap: The maximum initial position used to calculate delay.
    init(perRowDelay: TimeInterval, delayRowCap: Int) {
        _coordinator = StateObject(wrappedValue: EntranceCoordinator(perRowDelay: perRowDelay,
                                                                     delayRowCap: delayRowCap))
    }

    /// Supplies coordination state and measures the scroll-container viewport.
    ///
    /// - Parameter content: The scroll container supplied by SwiftUI.
    /// - Returns: The configured entrance container.
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
/// Applies and triggers a one-shot entrance effect for one SwiftUI row.
private struct EntranceEffectModifier: ViewModifier {
    /// The entrance effect resolved during animation.
    let effect: EntranceEffect
    /// The stable identity used by coordinated entrance state.
    let identity: AnyHashable?
    /// The row index used by the uncoordinated fallback path.
    let fallbackIndex: Int?
    /// The fallback delay between adjacent row indexes, in seconds.
    let fallbackPerRowDelay: TimeInterval
    /// The fallback maximum row index used to calculate delay.
    let fallbackDelayRowCap: Int

    /// The nearest entrance coordinator supplied by a container.
    @Environment(\.entranceCoordinator) private var coordinator
    /// The nearest measured entrance viewport height.
    @Environment(\.entranceViewport) private var viewport
    /// A value that animates from the effect's initial state to its settled state.
    @State private var appeared = false
    /// A value that prevents this modifier instance from scheduling twice.
    @State private var triggered = false

    /// Applies effect progress and installs either coordinated or fallback triggering.
    ///
    /// - Parameter content: The row content supplied by SwiftUI.
    /// - Returns: The entrance-enabled row.
    func body(content: Content) -> some View {
        // 已入场过的 index（回滑重建）直接按归位渲染，避免重建瞬间闪一帧滑出态。
        let alreadyEntered = identity.flatMap { coordinator?.hasEntered(id: $0) } ?? false
        let shown = appeared || alreadyEntered
        return content
            .modifier(EntranceProgressModifier(effect: effect, progress: shown ? 1 : 0))
            .background(visibilityProbe)
            .onAppear {
                // 无容器：退回 onAppear 一次性入场（无 latch，但已无回弹）。
                if coordinator == nil { fallbackTrigger() }
            }
    }

    /// A geometry probe that triggers when the row first intersects the viewport.
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

    /// Registers and animates a row through the nearest entrance coordinator.
    private func coordinatedTrigger() {
        guard !triggered else { return }
        guard let c = coordinator, let key = identity else {
            fallbackTrigger()   // 有容器但无 index：退化为按实例一次
            return
        }
        triggered = true
        if c.hasEntered(id: key) {
            appeared = true     // 已入场过：直接归位，不重播
            return
        }
        let delay = c.registerEntrance(id: key) ?? 0
        withAnimation(.linear(duration: effect.duration).delay(delay)) { appeared = true }
    }

    /// Starts the uncoordinated, instance-local entrance animation.
    private func fallbackTrigger() {
        guard !triggered else { return }
        triggered = true
        let delay = fallbackIndex.map { TimeInterval(min(max(0, $0), fallbackDelayRowCap)) * fallbackPerRowDelay } ?? 0
        withAnimation(.linear(duration: effect.duration).delay(delay)) { appeared = true }
    }
}

@available(iOS 17.0, macOS 14.0, *)
/// Resolves clamped progress through an entrance effect.
///
/// - Parameters:
///   - effect: The entrance effect to resolve.
///   - progress: Progress that is clamped to the closed range `0...1`.
/// - Returns: The effect output at the clamped progress.
func entranceOutput(for effect: EntranceEffect, progress: CGFloat) -> EffectOutput {
    effect.resolve(progress: max(0, min(1, progress)))
}

@available(iOS 17.0, macOS 14.0, *)
/// Converts animatable entrance progress into SwiftUI visual modifiers.
private struct EntranceProgressModifier: AnimatableModifier {
    /// The entrance effect resolved at each animation frame.
    let effect: EntranceEffect
    /// The current animatable entrance progress.
    var progress: CGFloat

    /// The scalar animation value bridged to ``progress``.
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Resolves and applies the current entrance-effect output.
    ///
    /// - Parameter content: The row content supplied by SwiftUI.
    /// - Returns: The transformed row content.
    func body(content: Content) -> some View {
        let out = entranceOutput(for: effect, progress: progress)
        let axis = out.rotationAxis ?? .z
        let anchor = UnitPoint(x: (out.anchor ?? .center).x, y: (out.anchor ?? .center).y)
        return content
            .offset(x: out.translation.x, y: out.translation.y)
            .scaleEffect(out.scale, anchor: anchor)
            .modifier(RotationModifier(radians: out.rotation, axis: axis, anchor: anchor))
            .opacity(out.alpha)
    }
}
#endif
