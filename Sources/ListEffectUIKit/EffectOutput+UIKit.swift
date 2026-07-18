#if canImport(UIKit)
import UIKit
import ListEffectCore

/// Applies a platform-independent effect output to a UIKit view.
///
/// Z-axis rotations use the view's affine transform. Other axes use the layer's
/// three-dimensional transform and perspective. Anchor-point changes preserve
/// the view's frame.
///
/// - Parameters:
///   - out: The effect values to apply.
///   - view: The view that receives the transform and opacity values.
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

/// Restores a view to the identity transform, full opacity, and center anchor.
///
/// - Parameter view: The view to reset.
func resetEffectOutput(on view: UIView) {
    view.transform = .identity
    view.layer.transform = CATransform3DIdentity
    view.alpha = 1
    setAnchorPointPreservingFrame(CGPoint(x: 0.5, y: 0.5), on: view)
}

/// Changes a layer anchor point without changing the view's frame.
///
/// - Parameters:
///   - anchorPoint: The normalized layer anchor point.
///   - view: The view whose layer anchor point changes.
private func setAnchorPointPreservingFrame(_ anchorPoint: CGPoint, on view: UIView) {
    guard view.layer.anchorPoint != anchorPoint else { return }
    let oldOrigin = view.frame.origin
    view.layer.anchorPoint = anchorPoint
    let newOrigin = view.frame.origin
    view.layer.position.x -= newOrigin.x - oldOrigin.x
    view.layer.position.y -= newOrigin.y - oldOrigin.y
}
#endif
