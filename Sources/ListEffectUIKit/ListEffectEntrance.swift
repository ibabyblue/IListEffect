#if canImport(UIKit)
import UIKit
import ListEffectCore
import QuartzCore

/// 入场驱动器：CADisplayLink 逐帧采样 effect.resolve(progress)，使 timing 真正生效。
/// 首次出现做动画；回滑再次出现直接归位。
public final class ListEffectEntrance {
    /// 相邻行错开延迟（秒）。
    public var perRowDelay: TimeInterval = 0.05
    /// 行索引参与延迟计算的上限，防止大列表延迟爆炸。
    public var delayRowCap: Int = 12

    var effect: EntranceEffect?
    var displayedIndexPaths = Set<IndexPath>()

    struct Animation {
        let contentView: UIView
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
            applyEffectOutput(effect.resolve(progress: progress), to: anim.contentView)
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
        for anim in animating.values { reset(anim.contentView) }
        animating.removeAll()
        displayedIndexPaths.removeAll()
    }

    public func handle(cell: UITableViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(contentView: cell.contentView, indexPath: indexPath, delay: delay)
    }
    public func handle(cell: UICollectionViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(contentView: cell.contentView, indexPath: indexPath, delay: delay)
    }

    public func prepare(cell: UITableViewCell) { prepare(contentView: cell.contentView) }
    public func prepare(cell: UICollectionViewCell) { prepare(contentView: cell.contentView) }
    private func prepare(contentView: UIView) {
        guard let effect = effect else { return }
        applyEffectOutput(effect.resolve(progress: 0), to: contentView)
    }

    private func handle(contentView: UIView, indexPath: IndexPath, delay: TimeInterval) {
        guard let effect = effect else { return }
        let id = ObjectIdentifier(contentView)
        if displayedIndexPaths.contains(indexPath) {
            animating.removeValue(forKey: id)
            reset(contentView)
            return
        }
        displayedIndexPaths.insert(indexPath)
        animating.removeValue(forKey: id)  // cell 复用：清旧条目
        // 兜底：handle 启动即设初始态，漏调 prepare 也不闪
        applyEffectOutput(effect.resolve(progress: 0), to: contentView)
        animating[id] = Animation(contentView: contentView, indexPath: indexPath, start: clock() + delay)
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
