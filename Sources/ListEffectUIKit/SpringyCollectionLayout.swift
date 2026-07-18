#if canImport(UIKit)
import UIKit

/// A collection-view flow layout that adds inertial, spring-like movement to cells.
///
/// The layout uses UIKit Dynamics to create a trailing wave while the user
/// scrolls. It is specific to `UICollectionView` because table views do not
/// expose a replaceable layout object.
public final class SpringyCollectionLayout: UICollectionViewFlowLayout {

    /// The spring damping ratio. Smaller values produce longer oscillation.
    public var springDamping: CGFloat = 0.8
    /// The spring oscillation frequency. Larger values feel faster and stiffer.
    public var springFrequency: CGFloat = 1.1
    /// The denominator used to calculate scroll resistance.
    ///
    /// Smaller values create more displacement and a more pronounced wave.
    public var scrollResistanceFactor: CGFloat = 1500

    /// The dynamic animator that owns cell attachment behaviors.
    private lazy var animator = UIDynamicAnimator(collectionViewLayout: self)
    /// The index paths currently represented by dynamic behaviors.
    private var visibleIndexPaths = Set<IndexPath>()
    /// The most recent vertical bounds delta.
    private var latestDelta: CGFloat = 0

    /// Creates a vertically scrolling springy flow layout with default spacing.
    public override init() {
        super.init()
        minimumLineSpacing = 12
        scrollDirection = .vertical
    }
    /// Creates the layout from an archive.
    ///
    /// - Parameter coder: The decoder containing archived layout state.
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Updates dynamic behaviors for items around the visible viewport.
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

    /// Returns dynamic layout attributes for items intersecting a rectangle.
    ///
    /// - Parameter rect: The rectangle to query in collection-view coordinates.
    /// - Returns: The dynamic attributes managed by the animator.
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        animator.items(in: rect) as? [UICollectionViewLayoutAttributes]
    }

    /// Returns dynamic layout attributes for a specific item.
    ///
    /// - Parameter indexPath: The index path of the requested item.
    /// - Returns: The animator's current attributes for the item.
    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        animator.layoutAttributesForCell(at: indexPath)
    }

    /// Offsets dynamic items in response to a collection-view bounds change.
    ///
    /// - Parameter newBounds: The collection view's proposed bounds.
    /// - Returns: `false` because the animator is updated directly.
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
