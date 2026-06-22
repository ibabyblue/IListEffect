#if canImport(UIKit)
import XCTest
import UIKit
import ListEffectCore
@testable import ListEffectUIKit

final class ListEffectEntranceTests: XCTestCase {
    private func makeCell() -> UICollectionViewCell {
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        return cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
    }

    func testAttachAndDetach() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect())
        entrance.detach()
        XCTAssertTrue(entrance.displayedIndexPaths.isEmpty)
        XCTAssertTrue(entrance.animating.isEmpty)
    }

    func testEntranceAssociatedObject() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertTrue(cv.entrance === cv.entrance, "同一 scrollView 的 entrance 应单例")
    }

    func testPrepareAppliesInitialState() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cell = makeCell()
        entrance.prepare(cell: cell)
        // prepare 同步设初始态：右偏 220 + alpha 0
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.alpha, 0, accuracy: 0.001)
    }

    func testPrepareWithoutAttachIsNoOp() {
        let entrance = ListEffectEntrance()  // 未 attach
        let cell = makeCell()
        entrance.prepare(cell: cell)
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertEqual(cell.contentView.alpha, 1, accuracy: 0.001)
    }

    func testHandleWithoutAttachIsNoOp() {
        let entrance = ListEffectEntrance()  // 未 attach
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertTrue(entrance.animating.isEmpty)
    }

    func testHandleRecordsAnimatingAndDisplayed() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cell = makeCell()
        let ip = IndexPath(item: 0, section: 0)
        entrance.handle(cell: cell, indexPath: ip)
        XCTAssertTrue(entrance.displayedIndexPaths.contains(ip))
        XCTAssertFalse(entrance.animating.isEmpty, "handle 后应标记动画中")
    }

    func testRedisplayDoesNotAnimate() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cell = makeCell()
        let ip = IndexPath(item: 0, section: 0)
        entrance.handle(cell: cell, indexPath: ip)   // 首次
        entrance.handle(cell: cell, indexPath: ip)   // 回滑
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertEqual(cell.contentView.alpha, 1, accuracy: 0.001)
        XCTAssertNil(entrance.animating[ObjectIdentifier(cell.contentView)], "回滑后应无进行中动画")
    }

    func testCellReuseRestartsAnimation() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        // 同一 contentView 复用给新 indexPath，应重新入场
        entrance.handle(cell: cell, indexPath: IndexPath(item: 5, section: 0))
        XCTAssertTrue(entrance.displayedIndexPaths.contains(IndexPath(item: 5, section: 0)))
        XCTAssertNotNil(entrance.animating[ObjectIdentifier(cell.contentView)], "复用后应重新标记动画中")
    }

    func testAnimationCompletesAndClears() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.05, timing: .easeOut))
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        let exp = expectation(description: "animation done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(cell.contentView.transform.tx, 0, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.transform.ty, 0, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.alpha, 1, accuracy: 0.05)
        XCTAssertNil(entrance.animating[ObjectIdentifier(cell.contentView)], "完成后应移出 animating")
    }

    func testEntranceDeallocatesAfterScrollViewReleased() {
        weak var weakEntrance: ListEffectEntrance?
        autoreleasepool {
            let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
            cv.entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
            cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
            cv.entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
            weakEntrance = cv.entrance
            XCTAssertNotNil(weakEntrance)
        }
        XCTAssertNil(weakEntrance, "entrance 泄漏")
    }
}
#endif
