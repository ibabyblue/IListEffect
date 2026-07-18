import CoreGraphics
import Foundation

/// A one-shot entrance effect driven by normalized progress.
///
/// Implementations are platform-independent value resolvers. UIKit and SwiftUI
/// integrations own the animation lifecycle and apply the resulting
/// ``EffectOutput`` values.
public protocol EntranceEffect {
    /// The duration of one item animation, measured in seconds.
    var duration: TimeInterval { get }

    /// Resolves the visual values for an entrance-animation progress value.
    ///
    /// - Parameter progress: Normalized progress, where `0` is the initial state
    ///   and `1` is the settled state.
    /// - Returns: The visual values to apply at the supplied progress.
    func resolve(progress: CGFloat) -> EffectOutput
}
