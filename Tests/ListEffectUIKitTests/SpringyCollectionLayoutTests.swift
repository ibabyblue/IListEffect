#if canImport(UIKit)
import XCTest
import UIKit
@testable import ListEffectUIKit

private final class FixedCDS: NSObject, UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 30 }
    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
    }
}

final class SpringyCollectionLayoutTests: XCTestCase {
    func testProducesAttributesForVisibleItems() {
        let layout = SpringyCollectionLayout()
        layout.itemSize = CGSize(width: 300, height: 80)
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let ds = FixedCDS()
        cv.dataSource = ds
        cv.reloadData()
        cv.layoutIfNeeded()

        let attrs = layout.layoutAttributesForElements(in: cv.bounds)
        XCTAssertNotNil(attrs)
        XCTAssertGreaterThan(attrs?.count ?? 0, 0)
        _ = ds
    }
}
#endif
