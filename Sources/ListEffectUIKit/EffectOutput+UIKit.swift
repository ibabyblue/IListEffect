#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 把 EffectOutput 应用到 UIView：仿射通道写 view.transform，3D 通道写 layer.transform，alpha 单独写。
/// ListEffectController（位置/跟随效果）与 ListEffectEntrance（入场效果）共用，避免两处逻辑漂移。
func applyEffectOutput(_ out: EffectOutput, to view: UIView) {
    if out.rotation == 0 {
        // 仿射通道：给 view.transform 赋值会同时归一化 layer.transform
        view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
            .scaledBy(x: out.scale, y: out.scale)
    } else {
        // 3D 通道：先清掉仿射状态，避免两条通道叠加
        view.transform = .identity
        var t = CATransform3DIdentity
        t.m34 = -1.0 / 800
        t = CATransform3DTranslate(t, out.translation.x, out.translation.y, 0)
        t = CATransform3DScale(t, out.scale, out.scale, 1)
        t = CATransform3DRotate(t, out.rotation, 1, 0, 0)
        view.layer.transform = t
    }
    view.alpha = out.alpha
}
#endif
