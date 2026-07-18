import CoreGraphics
import Foundation

/// A one-shot entrance effect that translates an item horizontally while fading it in.
public struct SlideInEffect: EntranceEffect {
    /// The curve used to map linear animation progress to translation progress.
    public enum Timing: Equatable {
        /// A cubic curve that decelerates toward the settled state.
        case easeOut

        /// A cubic curve that accelerates and then decelerates.
        case easeInOut

        /// An overshooting curve that settles back at the endpoint.
        case easeOutBack

        /// An underdamped oscillating curve.
        ///
        /// - Parameters:
        ///   - damping: The decay rate. Larger values settle more quickly.
        ///   - frequency: The oscillation frequency. Larger values oscillate more quickly.
        case spring(damping: CGFloat, frequency: CGFloat)

        /// Maps linear progress to the selected timing curve.
        ///
        /// - Parameter progress: Linear progress between `0` and `1`.
        /// - Returns: Curved progress. Overshooting curves may temporarily exceed `1`.
        func apply(to progress: CGFloat) -> CGFloat {
            let t = max(0, min(1, progress))
            if t <= 0 { return 0 }
            if t >= 1 { return 1 }
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

    /// The initial horizontal offset, measured in points.
    public var amplitude: CGFloat
    /// The duration of one item animation, measured in seconds.
    public var duration: TimeInterval
    /// The curve used to animate the horizontal translation.
    public var timing: Timing

    /// Creates a horizontal slide-in effect.
    ///
    /// - Parameters:
    ///   - amplitude: The initial horizontal offset in points.
    ///   - duration: The duration of one item animation in seconds.
    ///   - timing: The curve used for horizontal translation.
    public init(amplitude: CGFloat = 220,
                duration: TimeInterval = 0.5,
                timing: Timing = .easeOut) {
        self.amplitude = amplitude
        self.duration = duration
        self.timing = timing
    }

    /// Resolves translation and opacity for entrance-animation progress.
    ///
    /// - Parameter progress: Normalized progress from the initial state to the settled state.
    /// - Returns: An output that moves the item to its original position and fades it in.
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
