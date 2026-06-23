#if canImport(UIKit)
import UIKit
import ListEffectCore
import QuartzCore

/// 入场驱动器：CADisplayLink 逐帧采样 effect.resolve(progress)，使 timing 真正生效。
/// 首次出现做动画；回滑再次出现直接归位。
///
/// 注意：变换施加在 **cell 本身**（而非 cell.contentView）。UITableViewCell /
/// UICollectionViewCell 会在每次布局把 contentView 的 transform 复位，故必须变换 cell。
public final class ListEffectEntrance {
    /// 相邻行错开延迟（秒）。
    public var perRowDelay: TimeInterval = 0.05
    /// 行索引参与延迟计算的上限，防止大列表延迟爆炸。
    public var delayRowCap: Int = 12

    var effect: EntranceEffect?
    var displayedIndexPaths = Set<IndexPath>()
    var initialBatchTriggered = false

    struct Animation {
        let view: UIView
        let indexPath: IndexPath
        let start: CFTimeInterval
    }
    var animating: [ObjectIdentifier: Animation] = [:]

    /// 可注入时钟（测试用），默认 CACurrentMediaTime，与 displaylink.targetTimestamp 同源。
    var clock: () -> CFTimeInterval = { CACurrentMediaTime() }
    /// 测试入口：按时间戳推进所有活跃动画。displaylink 回调内部即调用它。
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

    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?

    public init() {}
    /// 由 UIScrollView.entrance 关联对象入口注入，弱引用避免循环。
    func bind(_ scrollView: UIScrollView) { self.scrollView = scrollView }

    public func attach(_ effect: EntranceEffect) {
        self.effect = effect
    }

    public func detach() {
        displayLink?.invalidate()
        displayLink = nil
        for anim in animating.values { reset(anim.view) }
        animating.removeAll()
        displayedIndexPaths.removeAll()
        initialBatchTriggered = false
    }

    /// 首批入场：对可见 cell 从上到下错开延迟动画。幂等，仅首次生效。
    /// - Parameter cells: 传 nil 则从绑定的 scrollView 取 visibleCells；测试可显式传入。
    public func animateInitialBatch(_ cells: [(view: UIView, indexPath: IndexPath)]? = nil) {
        guard !initialBatchTriggered, let effect = effect else { return }
        initialBatchTriggered = true
        let pairs = cells ?? visibleCellPairs() ?? []
        let sorted = pairs.sorted { lhs, rhs in
            let l = lhs.indexPath.section * 100_000 + lhs.indexPath.item
            let r = rhs.indexPath.section * 100_000 + rhs.indexPath.item
            return l < r
        }
        for (row, pair) in sorted.enumerated() {
            if displayedIndexPaths.contains(pair.indexPath) { continue }
            displayedIndexPaths.insert(pair.indexPath)
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

    public func handle(cell: UITableViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(view: cell, indexPath: indexPath, delay: delay)
    }
    public func handle(cell: UICollectionViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(view: cell, indexPath: indexPath, delay: delay)
    }

    public func prepare(cell: UITableViewCell) { prepare(view: cell) }
    public func prepare(cell: UICollectionViewCell) { prepare(view: cell) }
    private func prepare(view: UIView) {
        guard let effect = effect else { return }
        applyEffectOutput(effect.resolve(progress: 0), to: view)
    }

    private func handle(view: UIView, indexPath: IndexPath, delay: TimeInterval) {
        guard let effect = effect else { return }
        if !initialBatchTriggered { return }  // 首批由 animateInitialBatch 统一处理
        let id = ObjectIdentifier(view)
        if displayedIndexPaths.contains(indexPath) {
            animating.removeValue(forKey: id)
            reset(view)
            return
        }
        displayedIndexPaths.insert(indexPath)
        animating.removeValue(forKey: id)  // cell 复用：清旧条目
        // 兜底：handle 启动即设初始态，漏调 prepare 也不闪
        applyEffectOutput(effect.resolve(progress: 0), to: view)
        animating[id] = Animation(view: view, indexPath: indexPath, start: clock() + delay)
        ensureDisplayLinkRunning()
    }

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

    private func reset(_ v: UIView) {
        v.transform = .identity
        v.layer.transform = CATransform3DIdentity
        v.alpha = 1
    }

    deinit { displayLink?.invalidate() }
}

/// 弱 target：打破 CADisplayLink → entrance 的强引用环，使 entrance 可正常 deinit。
private final class DisplayLinkProxy {
    weak var target: ListEffectEntrance?
    init(target: ListEffectEntrance) { self.target = target }
    @objc func fire(_ link: CADisplayLink) { target?.tick(at: link.targetTimestamp) }
}
private var proxyKey: UInt8 = 0

private var entranceKey: UInt8 = 0

public extension UIScrollView {
    /// 入场动效入口。associated object 自持，懒创建；未 attach 时 handle 为 no-op。
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
