#if canImport(UIKit)
import XCTest
import UIKit
@testable import ListEffectUIKit

private final class FixedDataSource: NSObject, UITableViewDataSource {
    let rows: Int
    init(rows: Int) { self.rows = rows }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { rows }
    func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: nil)
    }
}

final class ListEffectHostTests: XCTestCase {
    func testTableViewVisibleItemsRestingCenter() {
        let tv = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        tv.rowHeight = 44
        let ds = FixedDataSource(rows: 50)
        tv.dataSource = ds
        tv.reloadData()
        tv.layoutIfNeeded()

        let items = tv.visibleItems()
        XCTAssertGreaterThan(items.count, 0)
        // 第一行静止中心 y ≈ rowHeight/2
        let firstCenterY = items.map { $0.restingCenter.y }.min() ?? -1
        XCTAssertEqual(firstCenterY, 22, accuracy: 1.0)
    }
}
#endif
