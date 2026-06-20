import CoreGraphics

/// 进入视口揭示：cell 越靠近视口中心越完整（scale→1、alpha→1），越靠边/越出界越收缩淡出。
public struct RevealEffect: PositionEffect {
    /// 边缘处的最小缩放。
    public var minScale: CGFloat

    public init(minScale: CGFloat = 0.8) {
        self.minScale = minScale
    }

    public func resolve(position: CGFloat) -> EffectOutput {
        let t = max(0, 1 - min(1, abs(position)))   // 居中=1，到/超过边缘=0
        return EffectOutput(scale: minScale + (1 - minScale) * t, alpha: t)
    }
}
