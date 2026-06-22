import UIKit
import ListEffectUIKit
import ListEffectCore

/// Slide In：cell 首次出现时从右侧滑入，回滑不再动画。使用库的 ListEffectEntrance。
final class CollectionDemoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]
    private var didInitialAnimate = false

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
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
        collectionView.entrance.attach(SlideInEffect())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateInitialBatchIfNeeded()
    }

    /// 首批：可见 cell 按行从上到下依次错开滑入。
    private func animateInitialBatchIfNeeded() {
        guard !didInitialAnimate, !collectionView.visibleCells.isEmpty else { return }
        didInitialAnimate = true
        let cells = collectionView.visibleCells.sorted {
            (collectionView.indexPath(for: $0)?.item ?? 0) < (collectionView.indexPath(for: $1)?.item ?? 0)
        }
        for cell in cells {
            guard let i = collectionView.indexPath(for: cell) else { continue }
            let row = i.item
            let delay = TimeInterval(min(row, collectionView.entrance.delayRowCap)) * collectionView.entrance.perRowDelay
            collectionView.entrance.handle(cell: cell, indexPath: i, delay: delay)
        }
    }

    func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt i: IndexPath) {
        // 首批由 viewDidAppear 批量处理；仅滚动进入的新 cell 走这里（delay=0，立即滑入）
        guard didInitialAnimate else { return }
        cv.entrance.handle(cell: cell, indexPath: i)
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 50 }

    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count]
        cell.contentView.layer.cornerRadius = 12
        cv.entrance.prepare(cell: cell)   // cell 创建/复用即预置初始态（右侧不可见），避免 willDisplay 跳变
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
