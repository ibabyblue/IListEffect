#if canImport(UIKit)
import UIKit

/// 滚动宿主抽象：暴露底层 scrollView 与"可见项 + 静止中心"。
public protocol ListEffectHost: AnyObject {
    var hostScrollView: UIScrollView { get }
    /// 当前可见项：视图本身 + 其在内容坐标系下的静止中心。
    func visibleItems() -> [(view: UIView, restingCenter: CGPoint)]
}

extension UITableView: ListEffectHost {
    public var hostScrollView: UIScrollView { self }

    public func visibleItems() -> [(view: UIView, restingCenter: CGPoint)] {
        (indexPathsForVisibleRows ?? []).compactMap { ip in
            guard let cell = cellForRow(at: ip) else { return nil }
            let r = rectForRow(at: ip)
            return (cell, CGPoint(x: r.midX, y: r.midY))
        }
    }
}

extension UICollectionView: ListEffectHost {
    public var hostScrollView: UIScrollView { self }

    public func visibleItems() -> [(view: UIView, restingCenter: CGPoint)] {
        indexPathsForVisibleItems.compactMap { ip in
            guard let cell = cellForItem(at: ip),
                  let attr = layoutAttributesForItem(at: ip) else { return nil }
            return (cell, attr.center)
        }
    }
}
#endif
