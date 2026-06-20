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

        // 第 0 行 center≈(160,22)，touch=.zero → resistance=(22+160)/2400≈0.0758
        // dy = min(10, 10*0.0758) ≈ 0.758
        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform.ty, 0.758, accuracy: 0.2)
    }

    func testTrackingDetachResets() {
        let tv = makeTable()
        tv.listEffect.attach(SpringyEffect())
        tv.contentOffset = CGPoint(x: 0, y: 10)
        tv.listEffect.detach()

        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform, .identity)
    }
}
#endif
