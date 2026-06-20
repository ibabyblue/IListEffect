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

private final class FixedCollectionDataSource: NSObject, UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 30 }
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
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

    func testCollectionViewVisibleItemsRestingCenter() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 320, height: 100)
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let ds = FixedCollectionDataSource()
        cv.dataSource = ds
        cv.reloadData()
        cv.layoutIfNeeded()

        let items = cv.visibleItems()
        XCTAssertGreaterThan(items.count, 0)
        // 第一个 item 静止中心 ≈ (160, 50)
        let first = items.min(by: { $0.restingCenter.y < $1.restingCenter.y })!
        XCTAssertEqual(first.restingCenter.y, 50, accuracy: 1.0)
        XCTAssertEqual(first.restingCenter.x, 160, accuracy: 1.0)
        _ = ds
    }
}
#endif
