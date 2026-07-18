import UIKit
import ListEffectUIKit
import ListEffectCore

/// Demonstrates one-shot collection-view entrances with `ListEffectEntrance`.
final class CollectionDemoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    /// The collection view whose cells receive entrance effects.
    private var collectionView: UICollectionView!
    /// The repeating colors used by example cells.
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]

    /// Builds the collection view and attaches a slide-in entrance effect.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Slide In"
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isHidden = true
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
        collectionView.entrance.attach(SlideInEffect())
    }

    /// Reveals the collection view and starts its initial staggered batch.
    ///
    /// - Parameter animated: A value indicating whether the appearance transition is animated.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.isHidden = false
        collectionView.entrance.animateInitialBatch()  // 一行收编首批 stagger
    }

    /// Handles a newly displayed cell through the entrance driver.
    ///
    /// - Parameters:
    ///   - cv: The collection view displaying the cell.
    ///   - cell: The cell entering the visible region.
    ///   - i: The cell's index path.
    func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt i: IndexPath) {
        cv.entrance.handle(cell: cell, indexPath: i)  // 滚入的新 cell：delay=0
    }

    /// Returns the number of sample items.
    ///
    /// - Parameters:
    ///   - cv: The collection view requesting the count.
    ///   - s: The requested section.
    /// - Returns: The fixed sample count.
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 50 }

    /// Dequeues and configures a sample cell.
    ///
    /// - Parameters:
    ///   - cv: The collection view requesting the cell.
    ///   - i: The cell's index path.
    /// - Returns: A prepared, colored sample cell.
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count]
        cell.contentView.layer.cornerRadius = 12
        cv.entrance.prepare(cell: cell)  // 可选优化：复用即预置初始态
        return cell
    }

    /// Returns the size of a sample cell.
    ///
    /// - Parameters:
    ///   - cv: The collection view containing the cell.
    ///   - layout: The active collection-view layout.
    ///   - i: The cell's index path.
    /// - Returns: A full-width sample size with horizontal margins.
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt i: IndexPath) -> CGSize {
        CGSize(width: cv.bounds.width - 32, height: 80)
    }
    /// Returns the section margins used by the sample catalog.
    ///
    /// - Parameters:
    ///   - cv: The collection view containing the section.
    ///   - layout: The active collection-view layout.
    ///   - s: The requested section.
    /// - Returns: The section inset values.
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        insetForSectionAt s: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }
}
