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

        // 第 0 行 restingCenter=(160,22)，换算到视图坐标 centerInView=(160, 22-10=12)；
        // touch=.zero → resistance=(12+160)/2400≈0.0717；dy=min(10, 10*0.0717)≈0.717
        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform.ty, 0.717, accuracy: 0.05)
    }

    func testTrackingDetachResets() {
        let tv = makeTable()
        tv.listEffect.attach(SpringyEffect())
        tv.contentOffset = CGPoint(x: 0, y: 10)
        tv.listEffect.detach()

        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform, .identity)
    }

    // 回归：下滑后 restingCenter（内容坐标）远超 touch（视图坐标），
    // 修复前 resistance≥1 + 累加放大会让偏移达到约 60~90pt（> 行高 44）→ cell 重叠。
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
        XCTAssertLessThan(maxTy, 10, "下滑后 tracking 偏移必须有界，否则 cell 重叠")
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
}
#endif
