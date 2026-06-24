import UIKit
import ListEffectUIKit
import ListEffectCore

/// Slide In：cell 首次出现时从右侧滑入，回滑不再动画。使用库的 ListEffectEntrance。
final class CollectionDemoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.isHidden = false
        collectionView.entrance.animateInitialBatch()  // 一行收编首批 stagger
    }

    func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt i: IndexPath) {
        cv.entrance.handle(cell: cell, indexPath: i)  // 滚入的新 cell：delay=0
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 50 }

    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count]
        cell.contentView.layer.cornerRadius = 12
        cv.entrance.prepare(cell: cell)  // 可选优化：复用即预置初始态
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
