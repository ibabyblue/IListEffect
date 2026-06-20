import CoreGraphics

/// 跟随型效果：依赖触摸位置与每帧位移，UIKit 专属。
/// `delta`：本帧滚动位移；`itemCenter`：cell 静止中心；`touch`：手指位置；`container`：滚动容器尺寸。
public protocol TrackingEffect {
    func resolve(delta: CGFloat,
                 itemCenter: CGPoint,
                 touch: CGPoint,
                 container: CGSize) -> EffectOutput
}
