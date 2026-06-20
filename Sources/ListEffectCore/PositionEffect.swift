import CoreGraphics

/// 位置型效果：输入归一化位置（-1 顶部外 … 0 居中 … 1 底部外），UIKit / SwiftUI 双端均可实现。
public protocol PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput
}
