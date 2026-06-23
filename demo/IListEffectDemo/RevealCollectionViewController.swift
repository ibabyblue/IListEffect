import UIKit
import ListEffectUIKit
import ListEffectCore

/// Reveal：cell 随滚动位置缩放/淡入。使用库的 PositionEffectDriver（scroll-linked）。
final class RevealCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]

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

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 50 }
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count]
        cell.contentView.layer.cornerRadius = 12
        return cell
    }
}
