import CoreGraphics

/// A scroll-linked reveal that scales and fades items near the viewport edges.
///
/// Items are fully visible at the viewport center and approach `minScale` with
/// zero opacity at or beyond either edge.
public struct RevealEffect: PositionEffect {
    /// The scale factor used at and beyond the viewport edges.
    public var minScale: CGFloat

    /// Creates a reveal effect.
    ///
    /// - Parameter minScale: The scale factor used at and beyond the viewport edges.
    public init(minScale: CGFloat = 0.8) {
        self.minScale = minScale
    }

    /// Resolves scale and opacity for a normalized viewport position.
    ///
    /// - Parameter position: The normalized position relative to the viewport center.
    /// - Returns: An output whose scale and opacity increase toward the center.
    public func resolve(position: CGFloat) -> EffectOutput {
        let t = max(0, 1 - min(1, abs(position)))   // 居中=1，到/超过边缘=0
        return EffectOutput(scale: minScale + (1 - minScale) * t, alpha: t)
    }
}
