#if canImport(UIKit)
import UIKit

/// UICollectionView 专属的弹性布局：基于 UIDynamics 真实弹簧（带惯性回弹），
/// 复刻"跟手滞后 + 回弹波浪"的手感。仅适用于 UICollectionView（UITableView 无可注入的 layout）。
public final class SpringyCollectionLayout: UICollectionViewFlowLayout {

    /// 阻尼：越小回弹越久越"果冻"。
    public var springDamping: CGFloat = 0.8
    /// 频率：越大越"硬/快"。
    public var springFrequency: CGFloat = 1.1
    /// 滚动阻力分母：越小跟手越"拖沓"、波浪越明显。
    public var scrollResistanceFactor: CGFloat = 1500

    private lazy var animator = UIDynamicAnimator(collectionViewLayout: self)
    private var visibleIndexPaths = Set<IndexPath>()
    private var latestDelta: CGFloat = 0

    public override init() {
        super.init()
        minimumLineSpacing = 12
        scrollDirection = .vertical
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        let rect = cv.bounds.insetBy(dx: 0, dy: -120)
        guard let items = super.layoutAttributesForElements(in: rect) else { return }
        let indexPaths = Set(items.map { $0.indexPath })

        for behavior in animator.behaviors {
            guard let att = behavior as? UIAttachmentBehavior,
                  let item = att.items.first as? UICollectionViewLayoutAttributes else { continue }
            if !indexPaths.contains(item.indexPath) {
                animator.removeBehavior(att)
                visibleIndexPaths.remove(item.indexPath)
            }
        }

        let touch = cv.panGestureRecognizer.location(in: cv)
        let newly = items.filter { !visibleIndexPaths.contains($0.indexPath) }
        for item in newly {
            let spring = UIAttachmentBehavior(item: item, attachedToAnchor: item.center)
            spring.length = 1
            spring.damping = springDamping
            spring.frequency = springFrequency
            if touch != .zero {
                var center = item.center
                let resistance = (abs(touch.y - spring.anchorPoint.y) + abs(touch.x - spring.anchorPoint.x)) / scrollResistanceFactor
                center.y += latestDelta < 0 ? max(latestDelta, latestDelta * resistance) : min(latestDelta, latestDelta * resistance)
                item.center = center
            }
            animator.addBehavior(spring)
            visibleIndexPaths.insert(item.indexPath)
        }
    }

    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        animator.items(in: rect) as? [UICollectionViewLayoutAttributes]
    }

    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        animator.layoutAttributesForCell(at: indexPath)
    }

    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let cv = collectionView else { return false }
        latestDelta = newBounds.origin.y - cv.bounds.origin.y
        let touch = cv.panGestureRecognizer.location(in: cv)
        for behavior in animator.behaviors {
            guard let att = behavior as? UIAttachmentBehavior,
                  let item = att.items.first as? UICollectionViewLayoutAttributes else { continue }
            let resistance = (abs(touch.y - att.anchorPoint.y) + abs(touch.x - att.anchorPoint.x)) / scrollResistanceFactor
            var center = item.center
            center.y += latestDelta < 0 ? max(latestDelta, latestDelta * resistance) : min(latestDelta, latestDelta * resistance)
            item.center = center
            animator.updateItem(usingCurrentState: item)
        }
        return false
    }
}
#endif
