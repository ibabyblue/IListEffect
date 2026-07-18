import UIKit
import ListEffectUIKit
import ListEffectCore

/// Demonstrates a UIKit scroll-linked reveal through `PositionEffectDriver`.
final class RevealCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    /// The collection view whose visible cells receive the reveal effect.
    private var collectionView: UICollectionView!
    /// The repeating colors used by example cells.
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]

    /// Builds the collection view and attaches its reveal effect.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reveal"
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.itemSize = CGSize(width: view.bounds.width - 32, height: 80)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
        collectionView.scrollEffect.attach(RevealEffect(minScale: 0.8))
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
    /// - Returns: A colored sample cell.
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count]
        cell.contentView.layer.cornerRadius = 12
        return cell
    }
}
