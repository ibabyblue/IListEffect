import UIKit
import ListEffectUIKit

final class SpringyCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let colors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple, .systemPink
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Springy (UIDynamics)"
        view.backgroundColor = .systemBackground

        let layout = SpringyCollectionLayout()
        layout.itemSize = CGSize(width: view.bounds.width - 32, height: 80)
        // 更硬：提高频率（弹簧更紧、回弹更快）+ 提高阻尼（少晃）
        layout.springFrequency = 2.2
        layout.springDamping = 0.92

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 40 }

    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count].withAlphaComponent(0.85)
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        return cell
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt i: IndexPath) -> CGSize {
        CGSize(width: cv.bounds.width - 32, height: 80)
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        insetForSectionAt s: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }
}
