import UIKit
import ListEffectUIKit

/// Demonstrates `SpringyCollectionLayout` with a vertically scrolling catalog.
final class SpringyCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    /// The collection view backed by the springy layout.
    private var collectionView: UICollectionView!
    /// The repeating colors used by example cells.
    private let colors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple, .systemPink
    ]

    /// Builds and tunes the springy collection view.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Springy (UIDynamics)"
        view.backgroundColor = .systemBackground

        let layout = SpringyCollectionLayout()
        layout.itemSize = CGSize(width: view.bounds.width - 32, height: 80)
        // 更硬：提高频率（弹簧更紧、回弹更快）+ 提高阻尼（少晃）
        layout.springFrequency = 2.2
        layout.springDamping = 0.92
        layout.scrollResistanceFactor = 3000

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
    }

    /// Returns the number of sample items.
    ///
    /// - Parameters:
    ///   - cv: The collection view requesting the count.
    ///   - s: The requested section.
    /// - Returns: The fixed sample count.
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 40 }

    /// Dequeues and configures a sample cell.
    ///
    /// - Parameters:
    ///   - cv: The collection view requesting the cell.
    ///   - i: The cell's index path.
    /// - Returns: A rounded, colored sample cell.
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count].withAlphaComponent(0.85)
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
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
