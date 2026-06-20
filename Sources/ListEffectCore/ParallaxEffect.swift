import CoreGraphics

/// 视差位移：cell 随其在视口中的位置上下偏移，产生纵深感。
public struct ParallaxEffect: PositionEffect {
    /// 最大偏移量（pt），在视口上/下边缘处取得。
    public var amplitude: CGFloat

    public init(amplitude: CGFloat = 24) {
        self.amplitude = amplitude
    }

    public func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(translation: CGPoint(x: 0, y: position * amplitude))
    }
}
