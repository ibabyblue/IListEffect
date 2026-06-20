#if canImport(SwiftUI)
import SwiftUI
import ListEffectCore

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    /// 为滚动容器中的行施加位置型效果。基于 `.scrollTransition`，需放在每个 row 上。
    func listEffect(_ effect: PositionEffect) -> some View {
        scrollTransition { content, phase in
            let out = effect.resolve(position: CGFloat(phase.value))
            return content
                .offset(x: out.translation.x, y: out.translation.y)
                .scaleEffect(out.scale)
                .rotation3DEffect(.radians(Double(out.rotation)), axis: (x: 1, y: 0, z: 0))
                .opacity(out.alpha)
        }
    }
}
#endif
