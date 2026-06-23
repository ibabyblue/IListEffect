#if canImport(UIKit)
import XCTest
import UIKit
import ListEffectCore
@testable import ListEffectUIKit

final class PositionEffectDriverTests: XCTestCase {
    func testNormalizedPositionCenterIsZero() {
        let p = PositionEffectDriver.normalizedPosition(cellCenter: 240, viewportCenter: 240, viewportHeight: 480)
        XCTAssertEqual(p, 0, accuracy: 0.001)
    }

    func testNormalizedPositionEdgeIsOne() {
        let p = PositionEffectDriver.normalizedPosition(cellCenter: 480, viewportCenter: 240, viewportHeight: 480)
        XCTAssertEqual(p, 1, accuracy: 0.001)
    }

    func testNormalizedPositionZeroViewportHeightIsZero() {
        // 边界：viewportHeight==0 不应除零，返回 0
        let p = PositionEffectDriver.normalizedPosition(cellCenter: 100, viewportCenter: 0, viewportHeight: 0)
        XCTAssertEqual(p, 0, accuracy: 0.001)
    }

    func testAttachAppliesEffectToVisibleCell() {
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        // 让一个 cell 进入可见并布局
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        cv.addSubview(cell)
        cell.frame = CGRect(x: 0, y: 200, width: 320, height: 80)  // cell.center.y=240 = 视口中心
        cv.layoutIfNeeded()

        cv.scrollEffect.attach(RevealEffect(minScale: 0.8))
        // 中心位置 → t=1 → alpha≈1（已应用）；不崩即为 attach smoke
        XCTAssertGreaterThan(cell.contentView.alpha, 0.9)
        cv.scrollEffect.detach()
    }

    func testScrollEffectAssociatedObjectIsSingleton() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertTrue(cv.scrollEffect === cv.scrollEffect)
    }
}
#endif
