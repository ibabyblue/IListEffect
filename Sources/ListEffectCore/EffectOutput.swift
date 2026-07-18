import CoreGraphics

/// A platform-independent axis used to rotate an effect in three dimensions.
public struct RotationAxis: Equatable {
    /// The x component of the axis vector.
    public var x: CGFloat
    /// The y component of the axis vector.
    public var y: CGFloat
    /// The z component of the axis vector.
    public var z: CGFloat

    /// Creates a rotation axis from its vector components.
    ///
    /// - Parameters:
    ///   - x: The x component of the axis vector.
    ///   - y: The y component of the axis vector.
    ///   - z: The z component of the axis vector.
    public init(x: CGFloat, y: CGFloat, z: CGFloat) { self.x = x; self.y = y; self.z = z }

    /// The z axis, which produces a two-dimensional rotation in the view plane.
    public static let z = RotationAxis(x: 0, y: 0, z: 1)

    /// The x axis, which produces a three-dimensional tilt around the horizontal axis.
    public static let x = RotationAxis(x: 1, y: 0, z: 0)
}

/// A platform-independent, normalized anchor point for rotation and scaling.
public struct AnchorPoint: Equatable {
    /// The horizontal coordinate, where `0` is the leading edge and `1` is the trailing edge.
    public var x: CGFloat
    /// The vertical coordinate, where `0` is the top edge and `1` is the bottom edge.
    public var y: CGFloat

    /// Creates an anchor point.
    ///
    /// - Parameters:
    ///   - x: The normalized horizontal coordinate.
    ///   - y: The normalized vertical coordinate.
    public init(x: CGFloat = 0.5, y: CGFloat = 0.5) { self.x = x; self.y = y }

    /// The center anchor point at `(0.5, 0.5)`.
    public static let center = AnchorPoint()
}

/// A platform-independent snapshot of the visual values produced by an effect.
///
/// UIKit and SwiftUI integrations translate the same output into their native
/// transform and opacity APIs.
public struct EffectOutput: Equatable {
    /// The horizontal and vertical translation, measured in points.
    public var translation: CGPoint
    /// The uniform scale factor.
    public var scale: CGFloat
    /// The rotation angle, measured in radians.
    public var rotation: CGFloat
    /// The opacity value, where `0` is transparent and `1` is opaque.
    public var alpha: CGFloat
    /// The rotation axis, or `nil` to use ``RotationAxis/z-type.property``.
    public var rotationAxis: RotationAxis?
    /// The Core Animation `m34` perspective value, or `nil` to use `-1/800`.
    public var perspective: CGFloat?
    /// The rotation and scale anchor, or `nil` to use ``AnchorPoint/center``.
    public var anchor: AnchorPoint?

    /// Creates a visual effect output.
    ///
    /// - Parameters:
    ///   - translation: The translation in points.
    ///   - scale: The uniform scale factor.
    ///   - rotation: The rotation angle in radians.
    ///   - alpha: The opacity value.
    ///   - rotationAxis: The optional three-dimensional rotation axis.
    ///   - perspective: The optional Core Animation `m34` perspective value.
    ///   - anchor: The optional normalized transform anchor.
    public init(translation: CGPoint = .zero,
                scale: CGFloat = 1,
                rotation: CGFloat = 0,
                alpha: CGFloat = 1,
                rotationAxis: RotationAxis? = nil,
                perspective: CGFloat? = nil,
                anchor: AnchorPoint? = nil) {
        self.translation = translation
        self.scale = scale
        self.rotation = rotation
        self.alpha = alpha
        self.rotationAxis = rotationAxis
        self.perspective = perspective
        self.anchor = anchor
    }
}
