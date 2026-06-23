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

    /// Bug2 回归：viewportCenter 必须等于 bounds.midY（已含 contentOffset），
    /// 不能再 + contentOffset.y。否则滚动后 viewportCenter 翻倍，cell 全部淡出（Reveal 全黑）。
    func testViewportCenterDoesNotDoubleCountOffset() {
        let sv = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        sv.contentSize = CGSize(width: 320, height: 5000)

        // 未滚动：viewportCenter = 0 + 480/2 = 240
        XCTAssertEqual(PositionEffectDriver.viewportCenter(of: sv), 240, accuracy: 0.001)

        // 滚动到 offset 700：bounds.origin.y 随之变 700，midY = 700 + 240 = 940（content 坐标）
        sv.contentOffset = CGPoint(x: 0, y: 700)
        XCTAssertEqual(PositionEffectDriver.viewportCenter(of: sv), 940, accuracy: 0.001,
                       "viewportCenter 应为 offset+midY=940，而非重复叠加的 1640")

        // 验证：滚动后，content 坐标 y=940 的 cell（正处视口中心）position≈0
        let pos = PositionEffectDriver.normalizedPosition(
            cellCenter: 940,
            viewportCenter: PositionEffectDriver.viewportCenter(of: sv),
            viewportHeight: sv.bounds.height)
        XCTAssertEqual(pos, 0, accuracy: 0.001, "视口中心的 cell 滚动后仍应 position≈0")
    }

    func testScrollEffectAssociatedObjectIsSingleton() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertTrue(cv.scrollEffect === cv.scrollEffect)
    }
}
#endif
