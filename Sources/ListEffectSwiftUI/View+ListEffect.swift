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

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    /// 入场效果：首次出现时 progress 0→1 驱动的一次性动画。
    /// 限制：LazyVStack 回滑销毁重建后会重播入场（SwiftUI 范式，与 UIKit 不一致）。
    func entranceEffect(_ effect: EntranceEffect) -> some View {
        modifier(EntranceEffectModifier(effect: effect))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct EntranceEffectModifier: ViewModifier {
    let effect: EntranceEffect
    @State private var appeared = false

    func body(content: Content) -> some View {
        // 取入场初始态；appeared 切换到 identity，由 withAnimation 在两端点间插值。
        // 用端点插值（而非逐帧 resolve+timing）避免 easeOutBack 回弹造成的方向错乱，
        // 并提高 LazyVStack 复用下的稳定性。已知限制：LazyVStack 复用/缓冲可能导致部分
        // cell 不重播入场——属 SwiftUI 范式限制。
        let initial = effect.resolve(progress: 0)
        let axis = initial.rotationAxis ?? .z
        let anchor = UnitPoint(x: (initial.anchor ?? .center).x, y: (initial.anchor ?? .center).y)
        return content
            .offset(x: appeared ? 0 : initial.translation.x,
                    y: appeared ? 0 : initial.translation.y)
            .scaleEffect(appeared ? 1 : initial.scale, anchor: anchor)
            .modifier(RotationModifier(radians: appeared ? 0 : initial.rotation, axis: axis, anchor: anchor))
            .opacity(appeared ? 1 : initial.alpha)
            .onAppear {
                withAnimation(.easeOut(duration: effect.duration)) { appeared = true }
            }
    }
}
#endif
