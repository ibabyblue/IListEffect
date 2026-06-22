import CoreGraphics
import Foundation

/// 从右滑入：cell 从右侧偏移位置滑回原位，同时淡入。
public struct SlideInEffect: EntranceEffect {
    public enum Timing {
        case easeOut, easeInOut, easeOutBack

        /// 把线性 progress（0→1）映射为缓动后的 t（可能略超 1，用于回弹）。
        func apply(to progress: CGFloat) -> CGFloat {
            let t = max(0, min(1, progress))
            switch self {
            case .easeOut:
                return 1 - pow(1 - t, 3)
            case .easeInOut:
                return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            case .easeOutBack:
                let c1: CGFloat = 1.70158
                let c3: CGFloat = c1 + 1
                return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
            }
        }
    }

    /// 横向滑入距离（pt），progress=0 时的右偏量。
    public var amplitude: CGFloat
    public var duration: TimeInterval
    public var timing: Timing

    public init(amplitude: CGFloat = 220,
                duration: TimeInterval = 0.5,
                timing: Timing = .easeOutBack) {
        self.amplitude = amplitude
        self.duration = duration
        self.timing = timing
    }

    public func resolve(progress: CGFloat) -> EffectOutput {
        let t = timing.apply(to: progress)
        return EffectOutput(
            translation: CGPoint(x: amplitude * (1 - t), y: 0),
            alpha: t
        )
    }
}
