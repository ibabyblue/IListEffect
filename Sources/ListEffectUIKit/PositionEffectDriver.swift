#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 位置型 scroll-linked 驱动器：KVO 监听 contentOffset，把每个可见 cell 的归一化位置
/// 交给 effect.resolve(position:) 并应用。不接管宿主 delegate。
public final class PositionEffectDriver: NSObject {
    private weak var scrollView: UIScrollView?
    private var effect: PositionEffect?
    private var observation: NSKeyValueObservation?

    public init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()
    }

    public func attach(_ effect: PositionEffect) {
        self.effect = effect
        startObserving()
        apply()
    }

    public func detach() {
        observation?.invalidate()
        observation = nil
        effect = nil
        guard let sv = scrollView else { return }
        resetAll(in: sv)
    }

    /// 归一化位置：居中 0，到/超视口边缘 ±1+。纯函数，可单测。
    static func normalizedPosition(cellCenter: CGFloat, viewportCenter: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight > 0 else { return 0 }
        return (cellCenter - viewportCenter) / (viewportHeight / 2)
    }

    private func startObserving() {
        observation?.invalidate()
        guard let sv = scrollView else { return }
        observation = sv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.apply() }
        }
    }

    private func apply() {
        guard let effect = effect, let sv = scrollView, sv.bounds.height > 0 else { return }
        let viewportCenter = sv.contentOffset.y + sv.bounds.midY
        forEachVisible(in: sv) { cellCenter, contentView in
            let position = Self.normalizedPosition(cellCenter: cellCenter,
                                                   viewportCenter: viewportCenter,
                                                   viewportHeight: sv.bounds.height)
            applyEffectOutput(effect.resolve(position: position), to: contentView)
        }
    }

    /// 遍历可见 cell，回调 (cell.center.y, cell.contentView)；UITableViewCell / UICollectionViewCell
    /// 各自有 contentView 但无共同父类声明，故按宿主类型分别提取。
    private func forEachVisible(in sv: UIScrollView, _ body: (CGFloat, UIView) -> Void) {
        if let tv = sv as? UITableView {
            for cell in tv.visibleCells { body(cell.center.y, cell.contentView) }
        } else if let cv = sv as? UICollectionView {
            for cell in cv.visibleCells { body(cell.center.y, cell.contentView) }
        }
    }

    private func resetAll(in sv: UIScrollView) {
        forEachVisible(in: sv) { _, contentView in reset(contentView) }
    }

    private func reset(_ v: UIView) {
        v.transform = .identity
        v.layer.transform = CATransform3DIdentity
        v.alpha = 1
    }

    deinit { observation?.invalidate() }
}

private var scrollEffectKey: UInt8 = 0

public extension UIScrollView {
    /// 位置型 scroll-linked 效果入口（关联对象自持）。
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
