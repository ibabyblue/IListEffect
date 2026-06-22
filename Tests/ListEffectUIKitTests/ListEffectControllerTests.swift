#if canImport(UIKit)
import XCTest
import UIKit
import ListEffectCore
@testable import ListEffectUIKit

private final class FixedDataSource: NSObject, UITableViewDataSource {
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { 50 }
    func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: nil)
    }
}

private final class FixedCollectionDataSource: NSObject, UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 50 }
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
    }
}

final class ListEffectControllerTests: XCTestCase {
    private var ds: FixedDataSource!

    private func makeTable() -> UITableView {
        let tv = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        tv.rowHeight = 44
        ds = FixedDataSource()
        tv.dataSource = ds
        tv.reloadData()
        tv.layoutIfNeeded()
        return tv
    }

    func testParallaxAppliesTransformOnAttach() {
        let tv = makeTable()
        tv.listEffect.attach(ParallaxEffect(amplitude: 24))

        // 第 0 行：restingCenter.y=22，视口 midY=240，half=240 → position=(22-240)/240
        let position = (22.0 - 240.0) / 240.0
        let expected = CGFloat(position) * 24
        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform.ty, expected, accuracy: 0.5)
    }

    func testDetachResetsTransform() {
        let tv = makeTable()
        tv.listEffect.attach(ParallaxEffect(amplitude: 24))
        tv.listEffect.detach()

        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform, .identity)
        XCTAssertEqual(cell.alpha, 1, accuracy: 0.001)
    }

    func testTrackingAppliesOffsetOnScroll() {
        let tv = makeTable()
        tv.listEffect.attach(SpringyEffect(stiffness: 2400))

        // 触发一次小幅滚动：delta=10
        tv.contentOffset = CGPoint(x: 0, y: 10)

        // 第 0 行 restingCenter=(160,22)，touch=.zero → resistance=(22+160)/2400≈0.0758
        // dy = min(10, 10*0.0758) ≈ 0.758（一次 onScroll 累加，未超上限）
        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform.ty, 0.758, accuracy: 0.05)
    }

    func testTrackingDetachResets() {
        let tv = makeTable()
        tv.listEffect.attach(SpringyEffect())
        tv.contentOffset = CGPoint(x: 0, y: 10)
        tv.listEffect.detach()

        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform, .identity)
    }

    // 回归：快速/持续滚动时，跟随位移必须被 maxLag(24) 夹住，
    // 不能累加到超过行高（44）而导致 cell 重叠。
    func testTrackingOffsetBoundedWhenScrolledDown() {
        let tv = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        tv.rowHeight = 44
        ds = FixedDataSource()           // 50 行，contentHeight≈2200
        tv.dataSource = ds
        tv.reloadData()
        tv.contentOffset = CGPoint(x: 0, y: 1200)
        tv.layoutIfNeeded()
        tv.listEffect.attach(SpringyEffect())

        var maxTy: CGFloat = 0
        var y: CGFloat = 1200
        for _ in 0..<20 {
            y += 20
            tv.contentOffset = CGPoint(x: 0, y: y)
            tv.layoutIfNeeded()
            tv.listEffect.tick()         // 模拟 displaylink 帧
            for c in tv.visibleCells { maxTy = max(maxTy, abs(c.transform.ty)) }
        }
        _ = ds
        XCTAssertLessThanOrEqual(maxTy, 24.5, "跟随位移必须被 maxLag 夹住，否则 cell 重叠")
    }

    func testControllerDeallocatesAfterScrollViewReleased() {
        weak var weakController: ListEffectController?
        autoreleasepool {
            let tv = makeTable()
            tv.listEffect.attach(SpringyEffect())
            weakController = tv.listEffect
        }
        XCTAssertNil(weakController, "controller leaked — CADisplayLink retain cycle?")
    }

    // 回归：UICollectionView 持续滚动时视差位移必须生效。
    // 历史 bug：库把位移写入 cell.transform，被 layout 的 apply(_ layoutAttributes:)
    // 每帧重置为 identity，导致 collection 上视差完全不可见。修复改为写 contentView.transform
    // （contentView 不受 apply 管理）。此测试模拟真实多帧滚动，锁定修复不被回退。
    func testParallaxSurvivesCollectionLayoutOnScroll() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 320, height: 80)
        layout.minimumLineSpacing = 12
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: layout)
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cds = FixedCollectionDataSource()
        cv.dataSource = cds
        cv.reloadData()
        cv.layoutIfNeeded()
        cv.listEffect.attach(ParallaxEffect(amplitude: 80))

        // 模拟真实滚动：每帧改 contentOffset（触发 KVO → apply 当前可见 cell）再 layout。
        var y: CGFloat = 0
        for _ in 0..<20 {
            y += 20
            cv.contentOffset = CGPoint(x: 0, y: y)
            cv.layoutIfNeeded()
        }

        // 持续滚动后，除最后一帧新进入的 cell 外，其余可见 cell 应已带上视差位移。
        let nonZero = cv.visibleCells.filter { abs($0.contentView.transform.ty) > 0.5 }.count
        XCTAssertGreaterThan(nonZero, cv.visibleCells.count / 2,
                             "滚动后多数可见 cell 应有视差位移，实际 \(nonZero)/\(cv.visibleCells.count)")
        _ = cds
    }
}
#endif
