#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 把 EffectOutput 应用到 UIView：
/// - axis==.z（含默认 nil）：2D，走 view.transform（rotated+scaled+translated）
/// - 其他轴：3D，走 layer.transform + 透视，清空 view.transform
/// - anchor != center：设 layer.anchorPoint（注意 CALayer 会相应平移 frame，调用方需自行补偿）
///
/// 注意：UIView.transform 的底层就是 layer.transform 的仿射投影，二者共享存储。
/// 因此 2D 通道只写 view.transform、不显式清 layer.transform；3D 通道先清 view.transform 再写 layer.transform。
func applyEffectOutput(_ out: EffectOutput, to view: UIView) {
    let axis = out.rotationAxis ?? .z
    let perspective = out.perspective ?? (-1.0 / 800)
    let anchor = out.anchor ?? .center

    if axis == .z {
        view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
            .rotated(by: out.rotation)
            .scaledBy(x: out.scale, y: out.scale)
    } else {
        // 3D 通道：清掉仿射状态，避免两条通道叠加
        view.transform = .identity
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, out.translation.x, out.translation.y, 0)
        t = CATransform3DRotate(t, out.rotation, axis.x, axis.y, axis.z)
        t = CATransform3DScale(t, out.scale, out.scale, 1)
        // 透视为最终矩阵的 m34，放在 scale/rotate 之后，避免被缩放/旋转改写
        t.m34 = perspective
        view.layer.transform = t
    }
    view.alpha = out.alpha
    setAnchorPointPreservingFrame(CGPoint(x: anchor.x, y: anchor.y), on: view)
}

func resetEffectOutput(on view: UIView) {
    view.transform = .identity
    view.layer.transform = CATransform3DIdentity
    view.alpha = 1
    setAnchorPointPreservingFrame(CGPoint(x: 0.5, y: 0.5), on: view)
}

private func setAnchorPointPreservingFrame(_ anchorPoint: CGPoint, on view: UIView) {
    guard view.layer.anchorPoint != anchorPoint else { return }
    let oldOrigin = view.frame.origin
    view.layer.anchorPoint = anchorPoint
    let newOrigin = view.frame.origin
    view.layer.position.x -= newOrigin.x - oldOrigin.x
    view.layer.position.y -= newOrigin.y - oldOrigin.y
}
#endif
