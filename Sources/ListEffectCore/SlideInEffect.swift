import CoreGraphics
import Foundation

/// 从右滑入：cell 从右侧偏移位置滑回原位，同时淡入。
public struct SlideInEffect: EntranceEffect {
    public enum Timing: Equatable {
        case easeOut, easeInOut, easeOutBack
        /// 欠阻尼弹簧：damping 越大衰减越快，frequency 越大振荡越快。
        case spring(damping: CGFloat, frequency: CGFloat)

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
            case .spring(let damping, let frequency):
                // 欠阻尼振荡：包络指数衰减，余弦振荡形成回弹。
                let omega = frequency * 2 * .pi * 2
                let envelope = exp(-damping * t * 6)
                return 1 - envelope * cos(omega * t)
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
        // alpha 前 ~20% 进度快速淡入到满，之后保持 1——让 translation 的横向滑入全程可见，
        // 而非「早期 alpha 低看不见位移、等可见时已到原位」的纯淡入观感。
        let alpha = min(1, max(0, progress * 5))
        return EffectOutput(
            translation: CGPoint(x: amplitude * (1 - t), y: 0),
            alpha: alpha
        )
    }
}
