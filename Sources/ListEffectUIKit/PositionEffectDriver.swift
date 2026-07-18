#if canImport(UIKit)
import UIKit
import ListEffectCore

/// Drives a scroll-linked position effect for visible table-view or collection-view cells.
///
/// The driver observes `contentOffset` without becoming the scroll view's delegate,
/// resolves each visible cell's normalized position, and applies the attached effect.
public final class PositionEffectDriver: NSObject {
    /// The scroll view observed by the driver.
    private weak var scrollView: UIScrollView?
    /// The currently attached position effect.
    private var effect: PositionEffect?
    /// The observation that refreshes visible cells as scrolling progresses.
    private var observation: NSKeyValueObservation?

    /// Creates a position-effect driver for a scroll view.
    ///
    /// - Parameter scrollView: The table view or collection view to observe.
    public init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()
    }

    /// Attaches an effect, starts observing scrolling, and immediately updates visible cells.
    ///
    /// - Parameter effect: The scroll-linked effect to apply.
    public func attach(_ effect: PositionEffect) {
        self.effect = effect
        startObserving()
        apply()
    }

    /// Stops observation, removes the effect, and restores visible cells.
    public func detach() {
        observation?.invalidate()
        observation = nil
        effect = nil
        guard let sv = scrollView else { return }
        resetAll(in: sv)
    }

    /// Immediately reapplies the effect to all currently visible cells.
    ///
    /// Use this after reloads, bounds changes, or data mutations that do not
    /// produce a `contentOffset` change.
    public func applyNow() {
        apply()
    }

    /// Calculates an item's normalized vertical position in a viewport.
    ///
    /// - Parameters:
    ///   - cellCenter: The item's center in scroll-content coordinates.
    ///   - viewportCenter: The viewport center in the same coordinate space.
    ///   - viewportHeight: The viewport height.
    /// - Returns: `0` at the center and approximately `-1` or `1` at the edges.
    static func normalizedPosition(cellCenter: CGFloat, viewportCenter: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight > 0 else { return 0 }
        return (cellCenter - viewportCenter) / (viewportHeight / 2)
    }

    /// Returns a scroll view's viewport center in content coordinates.
    ///
    /// `bounds.midY` already includes the content offset and must not be offset again.
    ///
    /// - Parameter scrollView: The scroll view whose viewport is measured.
    /// - Returns: The vertical viewport center in content coordinates.
    static func viewportCenter(of scrollView: UIScrollView) -> CGFloat {
        scrollView.bounds.midY
    }

    /// Starts a content-offset observation for the current scroll view.
    private func startObserving() {
        observation?.invalidate()
        guard let sv = scrollView else { return }
        observation = sv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            // contentOffset 的 KVO 回调本就在主线程同步触发，直接同步 apply，
            // 避免把 scroll-linked 效果推后一帧导致 Reveal 跟手滞后。
            self?.apply()
        }
    }

    /// Resolves and applies the attached effect to every visible cell.
    private func apply() {
        guard let effect = effect, let sv = scrollView, sv.bounds.height > 0 else { return }
        let viewportCenter = Self.viewportCenter(of: sv)
        forEachVisible(in: sv) { cellCenter, cell in
            let position = Self.normalizedPosition(cellCenter: cellCenter,
                                                   viewportCenter: viewportCenter,
                                                   viewportHeight: sv.bounds.height)
            Self.applyEffect(effect, to: cell, at: position)
        }
    }

    /// Resolves an effect at a position and applies it to a cell view.
    ///
    /// - Parameters:
    ///   - effect: The position effect to resolve.
    ///   - cell: The cell itself, rather than its content view.
    ///   - position: The cell's normalized viewport position.
    static func applyEffect(_ effect: PositionEffect, to cell: UIView, at position: CGFloat) {
        applyEffectOutput(effect.resolve(position: position), to: cell)
    }

    /// Visits every visible table-view or collection-view cell.
    ///
    /// - Parameters:
    ///   - sv: The scroll view whose cells are visited.
    ///   - body: A closure receiving each cell's vertical center and the cell itself.
    private func forEachVisible(in sv: UIScrollView, _ body: (CGFloat, UIView) -> Void) {
        if let tv = sv as? UITableView {
            for cell in tv.visibleCells { body(cell.center.y, cell) }
        } else if let cv = sv as? UICollectionView {
            for cell in cv.visibleCells { body(cell.center.y, cell) }
        }
    }

    /// Restores every visible cell in a scroll view.
    ///
    /// - Parameter sv: The scroll view whose visible cells are reset.
    private func resetAll(in sv: UIScrollView) {
        forEachVisible(in: sv) { _, contentView in reset(contentView) }
    }

    /// Restores a view to its uneffected state.
    ///
    /// - Parameter v: The view to reset.
    private func reset(_ v: UIView) {
        resetEffectOutput(on: v)
    }

    /// Invalidates observation when the driver is released.
    deinit { observation?.invalidate() }
}

/// The associated-object key that stores a scroll view's position-effect driver.
private var scrollEffectKey: UInt8 = 0

/// Position-effect conveniences for UIKit scroll views.
public extension UIScrollView {
    /// The lazily created position-effect driver associated with this scroll view.
    var scrollEffect: PositionEffectDriver {
        if let d = objc_getAssociatedObject(self, &scrollEffectKey) as? PositionEffectDriver {
            return d
        }
        let d = PositionEffectDriver(scrollView: self)
        objc_setAssociatedObject(self, &scrollEffectKey, d, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return d
    }
}
#endif
