#if canImport(UIKit)
import UIKit
import ListEffectCore

private final class EntranceDisplayLinkProxy: NSObject {
    weak var entrance: ListEffectEntrance?
    init(entrance: ListEffectEntrance) {
        self.entrance = entrance
        super.init()
    }
    @objc func tick() { entrance?.tick() }
}

/// 入场驱动器：在 willDisplay 时调用 handle，对 cell.contentView 做一次性入场动画。
/// 首次出现做动画；回滑再次出现直接归位，不动画。
public final class ListEffectEntrance {
    /// 相邻行错开延迟（秒），首批入场时从上到下依次。
    public var perRowDelay: TimeInterval = 0.05
    /// 同批内错开上限，防止大列表延迟爆炸。
    public var delayRowCap: Int = 12

    var effect: EntranceEffect?
    var displayedIndexPaths = Set<IndexPath>()
    struct AnimState {
        let contentView: UIView
        let start: CFTimeInterval
        let delay: TimeInterval
    }
    var animating: [ObjectIdentifier: AnimState] = [:]
    var lastHandleTime: CFTimeInterval = 0
    var batchIndex: Int = 0
    let batchInterval: CFTimeInterval = 0.05
    private var displayLink: CADisplayLink?
    private var proxy: EntranceDisplayLinkProxy?

    public init() {}

    deinit {
        // entrance 由 associated object 释放时，displayLink 可能仍挂在 runloop 上；
        // 不 invalidate 会导致 link + proxy 永久泄漏（proxy.entrance 弱引用失效后 tick 变 no-op，无法自查清场）。
        displayLink?.invalidate()
    }

    public func attach(_ effect: EntranceEffect) {
        self.effect = effect
    }

    public func detach() {
        displayLink?.invalidate()
        displayLink = nil
        proxy = nil
        for state in animating.values {
            state.contentView.transform = .identity
            state.contentView.layer.transform = CATransform3DIdentity
            state.contentView.alpha = 1
        }
        animating.removeAll()
        displayedIndexPaths.removeAll()
        batchIndex = 0
    }

    public func handle(cell: UITableViewCell, indexPath: IndexPath) {
        handle(contentView: cell.contentView, indexPath: indexPath)
    }

    public func handle(cell: UICollectionViewCell, indexPath: IndexPath) {
        handle(contentView: cell.contentView, indexPath: indexPath)
    }

    private func handle(contentView: UIView, indexPath: IndexPath) {
        guard let effect = effect else { return }
        let id = ObjectIdentifier(contentView)
        if displayedIndexPaths.contains(indexPath) {
            // 回滑：已显示过，移除残留动画，直接归位
            animating.removeValue(forKey: id)
            contentView.transform = .identity
            contentView.alpha = 1
            return
        }
        displayedIndexPaths.insert(indexPath)
        animating.removeValue(forKey: id)  // cell 复用：清除旧条目
        apply(effect.resolve(progress: 0), to: contentView)

        let now = CACurrentMediaTime()
        if now - lastHandleTime < batchInterval {
            batchIndex += 1
        } else {
            batchIndex = 0
        }
        lastHandleTime = now
        let delay = TimeInterval(min(batchIndex, delayRowCap)) * perRowDelay
        animating[id] = AnimState(contentView: contentView, start: now, delay: delay)
        startDisplayLinkIfNeeded()
    }

    func tick() {
        guard let effect = effect, effect.duration > 0 else { return }
        let now = CACurrentMediaTime()
        var done: [ObjectIdentifier] = []
        for (id, state) in animating {
            let elapsed = now - state.start - state.delay
            if elapsed < 0 { continue }
            let progress = min(1, elapsed / effect.duration)
            apply(effect.resolve(progress: progress), to: state.contentView)
            if progress >= 1 { done.append(id) }
        }
        for id in done { animating.removeValue(forKey: id) }
        if animating.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
            proxy = nil
        }
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let p = EntranceDisplayLinkProxy(entrance: self)
        let link = CADisplayLink(target: p, selector: #selector(EntranceDisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        proxy = p
        displayLink = link
    }

    private func apply(_ out: EffectOutput, to view: UIView) {
        if out.rotation == 0 {
            view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
                .scaledBy(x: out.scale, y: out.scale)
        } else {
            view.transform = .identity
            var t = CATransform3DIdentity
            t.m34 = -1.0 / 800
            t = CATransform3DTranslate(t, out.translation.x, out.translation.y, 0)
            t = CATransform3DScale(t, out.scale, out.scale, 1)
            t = CATransform3DRotate(t, out.rotation, 1, 0, 0)
            view.layer.transform = t
        }
        view.alpha = out.alpha
    }
}

private var entranceKey: UInt8 = 0

public extension UIScrollView {
    /// 入场动效入口。associated object 自持，懒创建；未 attach 时 handle 为 no-op。
    var entrance: ListEffectEntrance {
        if let e = objc_getAssociatedObject(self, &entranceKey) as? ListEffectEntrance {
            return e
        }
        let e = ListEffectEntrance()
        objc_setAssociatedObject(self, &entranceKey, e, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return e
    }
}
#endif
