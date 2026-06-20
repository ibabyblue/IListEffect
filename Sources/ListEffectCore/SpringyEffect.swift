import CoreGraphics

/// 弹性跟随：离手指越近跟随越"软"（滞后越多），整体随滚动产生波浪/果冻感。
/// 返回的是"本帧应叠加的位移增量"，由 UIKit 驱动器累加并松手回弹。
public struct SpringyEffect: TrackingEffect {
    /// 弹簧硬度。越大跟手越紧（滞后越小），越小越拖沓。
    public var stiffness: CGFloat

    public init(stiffness: CGFloat = 2400) {
        self.stiffness = stiffness
    }

    public func resolve(delta: CGFloat,
                        itemCenter: CGPoint,
                        touch: CGPoint,
                        container: CGSize) -> EffectOutput {
        let resistance = (abs(touch.y - itemCenter.y) + abs(touch.x - itemCenter.x)) / stiffness
        let dy = delta < 0 ? max(delta, delta * resistance) : min(delta, delta * resistance)
        return EffectOutput(translation: CGPoint(x: 0, y: dy))
    }
}
