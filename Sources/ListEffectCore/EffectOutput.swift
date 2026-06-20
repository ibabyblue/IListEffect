import CoreGraphics

/// 效果的输出，UIKit 与 SwiftUI 两端共用。
public struct EffectOutput: Equatable {
    public var translation: CGPoint
    public var scale: CGFloat
    /// 旋转弧度，用于 2D/3D 旋转。
    public var rotation: CGFloat
    public var alpha: CGFloat

    public init(translation: CGPoint = .zero,
                scale: CGFloat = 1,
                rotation: CGFloat = 0,
                alpha: CGFloat = 1) {
        self.translation = translation
        self.scale = scale
        self.rotation = rotation
        self.alpha = alpha
    }
}
