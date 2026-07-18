#if canImport(UIKit)
import UIKit
import ListEffectCore
import QuartzCore

/// Drives one-shot entrance effects for table-view and collection-view cells.
///
/// The driver samples an `EntranceEffect` with a display link.
/// Each stable item identity animates only once until ``resetEnteredState()`` is
/// called. Transforms are applied to the cell itself because cell layout may
/// reset transforms on its content view.
public final class ListEffectEntrance {
    /// The delay between adjacent items in the initial visible batch, in seconds.
    public var perRowDelay: TimeInterval = 0.05
    /// The maximum initial-batch position used to calculate staggered delay.
    public var delayRowCap: Int = 12

    /// The currently attached entrance effect.
    var effect: EntranceEffect?
    /// Index paths that have entered during the current driver lifecycle.
    var displayedIndexPaths = Set<IndexPath>()
    /// Stable item identities that have entered during the current driver lifecycle.
    var displayedIDs = Set<AnyHashable>()
    /// A value indicating whether initial-batch orchestration has started.
    var initialBatchTriggered = false

    /// The state required to advance one active cell animation.
    struct Animation {
        /// The cell view receiving effect values.
        let view: UIView
        /// The cell's index path when the animation was scheduled.
        let indexPath: IndexPath
        /// The media timestamp at which the animation begins.
        let start: CFTimeInterval
    }
    /// Active animations keyed by cell object identity.
    var animating: [ObjectIdentifier: Animation] = [:]

    /// The media-time provider used to schedule animations.
    var clock: () -> CFTimeInterval = { CACurrentMediaTime() }

    /// Advances all active animations to a media timestamp.
    ///
    /// - Parameter timestamp: A timestamp in the same time base as ``clock``.
    func tick(at timestamp: CFTimeInterval) {
        guard let effect = effect else { return }
        var finished: [ObjectIdentifier] = []
        for (id, anim) in animating {
            let elapsed = timestamp - anim.start
            if elapsed < 0 { continue }
            let progress = CGFloat(max(0, min(1, elapsed / effect.duration)))
            applyEffectOutput(effect.resolve(progress: progress), to: anim.view)
            if progress >= 1 { finished.append(id) }
        }
        for id in finished { animating.removeValue(forKey: id) }
        if animating.isEmpty { displayLink?.isPaused = true }
    }

    /// The scroll view that owns this driver through an associated object.
    private weak var scrollView: UIScrollView?
    /// The display link used to sample active entrance animations.
    private var displayLink: CADisplayLink?

    /// Creates an unattached entrance-effect driver.
    public init() {}

    /// Associates the driver with a scroll view without retaining it.
    ///
    /// - Parameter scrollView: The table view or collection view to observe.
    func bind(_ scrollView: UIScrollView) { self.scrollView = scrollView }

    /// Attaches an entrance effect for subsequent cell handling.
    ///
    /// - Parameter effect: The entrance effect to drive.
    public func attach(_ effect: EntranceEffect) {
        self.effect = effect
    }

    /// Stops active animations, restores affected cells, and clears entrance state.
    public func detach() {
        displayLink?.invalidate()
        displayLink = nil
        for anim in animating.values { reset(anim.view) }
        animating.removeAll()
        resetEnteredState()
        initialBatchTriggered = false
    }

    /// Clears recorded item identities so items can animate again.
    ///
    /// Call this after replacing or reloading the data source when the new content
    /// should replay its entrance animations.
    public func resetEnteredState() {
        displayedIndexPaths.removeAll()
        displayedIDs.removeAll()
    }

    /// Animates the first visible batch in index-path order with staggered delays.
    ///
    /// This method is idempotent until the driver is detached.
    ///
    /// - Parameter cells: Explicit cells to animate, or `nil` to read the bound
    ///   scroll view's visible cells.
    public func animateInitialBatch(_ cells: [(view: UIView, indexPath: IndexPath)]? = nil) {
        animateInitialBatch(identified: cells?.map { (view: $0.view, id: AnyHashable($0.indexPath), indexPath: $0.indexPath) })
    }

    /// Animates the first visible batch using stable business identities.
    ///
    /// - Parameter cells: Explicit cells and stable identities, or `nil` to use
    ///   visible cells with their index paths as identities.
    public func animateInitialBatch(identified cells: [(view: UIView, id: AnyHashable, indexPath: IndexPath)]?) {
        guard !initialBatchTriggered, let effect = effect else { return }
        initialBatchTriggered = true
        let pairs = cells ?? visibleCellPairs()?.map { (view: $0.view, id: AnyHashable($0.indexPath), indexPath: $0.indexPath) } ?? []
        let sorted = pairs.sorted { lhs, rhs in
            let l = lhs.indexPath.section * 100_000 + lhs.indexPath.item
            let r = rhs.indexPath.section * 100_000 + rhs.indexPath.item
            return l < r
        }
        for (row, pair) in sorted.enumerated() {
            if displayedIDs.contains(pair.id) { continue }
            displayedIndexPaths.insert(pair.indexPath)
            displayedIDs.insert(pair.id)
            let id = ObjectIdentifier(pair.view)
            animating.removeValue(forKey: id)
            applyEffectOutput(effect.resolve(progress: 0), to: pair.view)
            let delay = TimeInterval(min(row, delayRowCap)) * perRowDelay
            animating[id] = Animation(view: pair.view,
                                      indexPath: pair.indexPath,
                                      start: clock() + delay)
        }
        if !animating.isEmpty { ensureDisplayLinkRunning() }
    }

    /// Returns visible table-view or collection-view cells with their index paths.
    ///
    /// - Returns: Visible cell pairs, `nil` when no scroll view is bound, or an
    ///   empty array for an unsupported scroll-view subclass.
    private func visibleCellPairs() -> [(view: UIView, indexPath: IndexPath)]? {
        guard let sv = scrollView else { return nil }
        if let tv = sv as? UITableView {
            return tv.visibleCells.compactMap { cell in
                guard let ip = tv.indexPath(for: cell) else { return nil }
                return (cell, ip)
            }
        }
        if let cv = sv as? UICollectionView {
            return cv.visibleCells.compactMap { cell in
                guard let ip = cv.indexPath(for: cell) else { return nil }
                return (cell, ip)
            }
        }
        return []
    }

    /// Handles a table-view cell using its index path as its entrance identity.
    ///
    /// - Parameters:
    ///   - cell: The visible table-view cell.
    ///   - indexPath: The cell's current index path.
    ///   - delay: Additional delay before animation begins, in seconds.
    public func handle(cell: UITableViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(view: cell, indexPath: indexPath, delay: delay)
    }
    /// Handles a collection-view cell using its index path as its entrance identity.
    ///
    /// - Parameters:
    ///   - cell: The visible collection-view cell.
    ///   - indexPath: The cell's current index path.
    ///   - delay: Additional delay before animation begins, in seconds.
    public func handle(cell: UICollectionViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(view: cell, indexPath: indexPath, delay: delay)
    }
    /// Handles a table-view cell using a stable business identity.
    ///
    /// - Parameters:
    ///   - cell: The visible table-view cell.
    ///   - id: A stable identity that survives insertion, deletion, and reordering.
    ///   - indexPath: The cell's current index path.
    ///   - delay: Additional delay before animation begins, in seconds.
    public func handle(cell: UITableViewCell, id: AnyHashable, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(view: cell, id: id, indexPath: indexPath, delay: delay)
    }
    /// Handles a collection-view cell using a stable business identity.
    ///
    /// - Parameters:
    ///   - cell: The visible collection-view cell.
    ///   - id: A stable identity that survives insertion, deletion, and reordering.
    ///   - indexPath: The cell's current index path.
    ///   - delay: Additional delay before animation begins, in seconds.
    public func handle(cell: UICollectionViewCell, id: AnyHashable, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(view: cell, id: id, indexPath: indexPath, delay: delay)
    }

    /// Applies the attached effect's initial state to a table-view cell.
    ///
    /// - Parameter cell: The cell to prepare before display.
    public func prepare(cell: UITableViewCell) { prepare(view: cell) }
    /// Applies the attached effect's initial state to a collection-view cell.
    ///
    /// - Parameter cell: The cell to prepare before display.
    public func prepare(cell: UICollectionViewCell) { prepare(view: cell) }

    /// Applies the attached effect's initial state to a view.
    ///
    /// - Parameter view: The cell view to prepare.
    private func prepare(view: UIView) {
        guard let effect = effect else { return }
        applyEffectOutput(effect.resolve(progress: 0), to: view)
    }

    /// Handles a view using its index path as its stable identity.
    ///
    /// - Parameters:
    ///   - view: The cell view to animate or restore.
    ///   - indexPath: The cell's current index path.
    ///   - delay: Additional delay before animation begins, in seconds.
    private func handle(view: UIView, indexPath: IndexPath, delay: TimeInterval) {
        handle(view: view, id: AnyHashable(indexPath), indexPath: indexPath, delay: delay)
    }

    /// Schedules a view's first entrance animation or restores an already-entered item.
    ///
    /// - Parameters:
    ///   - view: The cell view to animate or restore.
    ///   - stableID: The item's stable entrance identity.
    ///   - indexPath: The cell's current index path.
    ///   - delay: Additional delay before animation begins, in seconds.
    private func handle(view: UIView, id stableID: AnyHashable, indexPath: IndexPath, delay: TimeInterval) {
        guard let effect = effect else { return }
        if !initialBatchTriggered { return }  // 首批由 animateInitialBatch 统一处理
        let id = ObjectIdentifier(view)
        if displayedIDs.contains(stableID) {
            animating.removeValue(forKey: id)
            reset(view)
            return
        }
        displayedIndexPaths.insert(indexPath)
        displayedIDs.insert(stableID)
        animating.removeValue(forKey: id)  // cell 复用：清旧条目
        // 兜底：handle 启动即设初始态，漏调 prepare 也不闪
        applyEffectOutput(effect.resolve(progress: 0), to: view)
        animating[id] = Animation(view: view, indexPath: indexPath, start: clock() + delay)
        ensureDisplayLinkRunning()
    }

    /// Creates or resumes the display link used by active animations.
    private func ensureDisplayLinkRunning() {
        if displayLink == nil {
            let proxy = DisplayLinkProxy(target: self)
            let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            // proxy 由 displaylink 持有；entrance 释放后 proxy.target=nil，回调 no-op。
            objc_setAssociatedObject(self, &proxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        displayLink?.isPaused = false
    }

    /// Restores a cell view to its uneffected state.
    ///
    /// - Parameter v: The cell view to reset.
    private func reset(_ v: UIView) {
        resetEffectOutput(on: v)
    }

    /// Invalidates the display link when the driver is released.
    deinit { displayLink?.invalidate() }
}

/// A weak display-link target that avoids retaining the entrance driver.
private final class DisplayLinkProxy {
    /// The entrance driver that receives display-link timestamps.
    weak var target: ListEffectEntrance?
    /// Creates a proxy for an entrance driver.
    ///
    /// - Parameter target: The entrance driver to notify without retaining it.
    init(target: ListEffectEntrance) { self.target = target }
    /// Forwards a display-link timestamp to the entrance driver.
    ///
    /// - Parameter link: The display link that fired.
    @objc func fire(_ link: CADisplayLink) { target?.tick(at: link.targetTimestamp) }
}
/// The associated-object key that retains a display-link proxy.
private var proxyKey: UInt8 = 0

/// The associated-object key that stores a scroll view's entrance driver.
private var entranceKey: UInt8 = 0

/// Entrance-effect conveniences for UIKit scroll views.
public extension UIScrollView {
    /// The lazily created entrance-effect driver associated with this scroll view.
    ///
    /// Calling cell-handling methods before attaching an effect is a no-op.
    var entrance: ListEffectEntrance {
        if let e = objc_getAssociatedObject(self, &entranceKey) as? ListEffectEntrance {
            return e
        }
        let e = ListEffectEntrance()
        e.bind(self)
        objc_setAssociatedObject(self, &entranceKey, e, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return e
    }
}
#endif
