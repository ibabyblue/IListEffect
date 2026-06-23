import CoreGraphics

/// 3D 旋转轴。平台无关（纯 CGFloat），Core 不依赖 UIKit/SwiftUI。
public struct RotationAxis: Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var z: CGFloat
    public init(x: CGFloat, y: CGFloat, z: CGFloat) { self.x = x; self.y = y; self.z = z }
    /// 绕 Z 轴：2D 平面旋转（默认）。
    public static let z = RotationAxis(x: 0, y: 0, z: 1)
    /// 绕 X 轴：3D 倾斜。
    public static let x = RotationAxis(x: 1, y: 0, z: 0)
}

/// 旋转/缩放锚点，归一化 0…1（平台无关）。
public struct AnchorPoint: Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public init(x: CGFloat = 0.5, y: CGFloat = 0.5) { self.x = x; self.y = y }
    public static let center = AnchorPoint()
}

/// 效果的输出，UIKit 与 SwiftUI 两端共用。
public struct EffectOutput: Equatable {
    public var translation: CGPoint
    public var scale: CGFloat
    /// 旋转弧度。
    public var rotation: CGFloat
    public var alpha: CGFloat
    /// 旋转轴；nil → 默认绕 Z（2D）。
    public var rotationAxis: RotationAxis?
    /// 3D 透视（m34）；nil → 默认 -1/800。
    public var perspective: CGFloat?
    /// 旋转/缩放锚点；nil → 默认中心。
    public var anchor: AnchorPoint?

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
