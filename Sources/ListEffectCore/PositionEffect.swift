import CoreGraphics

/// A scroll-linked effect driven by an item's normalized viewport position.
///
/// Position `0` represents the viewport center. Values near `-1` and `1`
/// represent the leading and trailing edges, respectively.
public protocol PositionEffect {
    /// Resolves the visual values for an item's viewport position.
    ///
    /// - Parameter position: The normalized position relative to the viewport center.
    /// - Returns: The visual values to apply at the supplied position.
    func resolve(position: CGFloat) -> EffectOutput
}
