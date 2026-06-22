#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 入场驱动器：在 willDisplay 时调用 handle，对 cell.contentView 做一次性入场动画。
/// 首次出现做动画；回滑再次出现直接归位，不动画。
public final class ListEffectEntrance {
    /// 相邻行错开延迟（秒），首批入场时从上到下依次。由调用方在 handle(delay:) 传入。
    public var perRowDelay: TimeInterval = 0.05
    /// 行索引参与延迟计算的上限，防止大列表延迟爆炸。
    public var delayRowCap: Int = 12

    var effect: EntranceEffect?
    var displayedIndexPaths = Set<IndexPath>()
    /// 正在动画的 contentView，用于 detach 还原。
    var animating: [ObjectIdentifier: UIView] = [:]

    public init() {}

    public func attach(_ effect: EntranceEffect) {
        self.effect = effect
    }

    public func detach() {
        for contentView in animating.values {
            contentView.transform = .identity
            contentView.layer.transform = CATransform3DIdentity
            contentView.alpha = 1
        }
        animating.removeAll()
        displayedIndexPaths.removeAll()
    }

    public func handle(cell: UITableViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(contentView: cell.contentView, indexPath: indexPath, delay: delay)
    }

    public func handle(cell: UICollectionViewCell, indexPath: IndexPath, delay: TimeInterval = 0) {
        handle(contentView: cell.contentView, indexPath: indexPath, delay: delay)
    }

    /// 在 cellForItemAt 调用，把 cell 预置为入场初始态。
    /// cell 创建/复用时就处于初始态，避免 willDisplay 时 handle 从原位跳到初始态的闪烁
    /// （快速滚动时 willDisplay 可能拖到视口内才触发，跳变可见）。
    public func prepare(cell: UITableViewCell) {
        prepare(contentView: cell.contentView)
    }

    public func prepare(cell: UICollectionViewCell) {
        prepare(contentView: cell.contentView)
    }

    private func prepare(contentView: UIView) {
        guard let effect = effect else { return }
        applyEffectOutput(effect.resolve(progress: 0), to: contentView)
    }

    private func handle(contentView: UIView, indexPath: IndexPath, delay: TimeInterval) {
        guard let effect = effect else { return }
        let id = ObjectIdentifier(contentView)
        if displayedIndexPaths.contains(indexPath) {
            // 回滑：已显示过，移除残留动画，直接归位
            animating.removeValue(forKey: id)
            contentView.transform = .identity
            contentView.layer.transform = CATransform3DIdentity
            contentView.alpha = 1
            return
        }
        displayedIndexPaths.insert(indexPath)
        animating.removeValue(forKey: id)  // cell 复用：清除旧条目

        let initial = effect.resolve(progress: 0)
        let final = effect.resolve(progress: 1)
        applyEffectOutput(initial, to: contentView)
        animating[id] = contentView

        let duration = effect.duration
        UIView.animate(withDuration: duration,
                       delay: delay,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: [.curveEaseOut]) {
            applyEffectOutput(final, to: contentView)
        } completion: { [weak self] _ in
            self?.animating.removeValue(forKey: id)
        }
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
