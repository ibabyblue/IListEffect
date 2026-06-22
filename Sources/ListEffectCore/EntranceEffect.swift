import CoreGraphics
import Foundation

/// 入场型效果：cell 首次出现时由 progress(0→1) 驱动的一次性动画。
/// 与 PositionEffect 对称——纯函数，无 UIKit 依赖。
public protocol EntranceEffect {
    /// 单个 cell 动画时长（秒），驱动器据此推进 progress。
    var duration: TimeInterval { get }
    /// progress: 0 = 初始未到位，1 = 归位完成。
    func resolve(progress: CGFloat) -> EffectOutput
}
