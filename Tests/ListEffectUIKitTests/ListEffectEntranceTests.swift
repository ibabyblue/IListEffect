#if canImport(UIKit)
import XCTest
import UIKit
import ListEffectCore
@testable import ListEffectUIKit

final class ListEffectEntranceTests: XCTestCase {
    func testAttachAndDetach() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect())
        entrance.detach()
        // detach 后内部状态清空
        XCTAssertTrue(entrance.displayedIndexPaths.isEmpty)
        XCTAssertTrue(entrance.animating.isEmpty)
    }

    func testEntranceAssociatedObject() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertNotNil(cv.entrance)
        XCTAssertTrue(cv.entrance === cv.entrance, "同一 scrollView 的 entrance 应单例")
    }

    func testHandleAppliesInitialState() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))

        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))

        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        // 初始态：右偏 220 + alpha 0
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.alpha, 0, accuracy: 0.001)
        XCTAssertTrue(entrance.displayedIndexPaths.contains(IndexPath(item: 0, section: 0)))
        XCTAssertFalse(entrance.animating.isEmpty)
    }

    func testHandleWithoutAttachIsNoOp() {
        let entrance = ListEffectEntrance()  // 未 attach
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertTrue(entrance.animating.isEmpty)
    }

    func testRedisplayDoesNotAnimate() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let ip = IndexPath(item: 0, section: 0)
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: ip)

        entrance.handle(cell: cell, indexPath: ip)   // 首次
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5)

        entrance.handle(cell: cell, indexPath: ip)   // 回滑
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertEqual(cell.contentView.alpha, 1)
        XCTAssertTrue(entrance.animating.isEmpty, "回滑后应无进行中动画")
    }

    func testBatchDelayStaggered() throws {
        let entrance = ListEffectEntrance()
        entrance.perRowDelay = 0.05
        entrance.delayRowCap = 12
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")

        // 同批：连续 3 个 handle，间隔 < 50ms
        let c0 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        let c1 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 1, section: 0))
        let c2 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 2, section: 0))
        entrance.handle(cell: c0, indexPath: IndexPath(item: 0, section: 0))
        entrance.handle(cell: c1, indexPath: IndexPath(item: 1, section: 0))
        entrance.handle(cell: c2, indexPath: IndexPath(item: 2, section: 0))

        let d1 = try XCTUnwrap(entrance.animating[ObjectIdentifier(c1.contentView)]?.delay)
        let d2 = try XCTUnwrap(entrance.animating[ObjectIdentifier(c2.contentView)]?.delay)
        XCTAssertEqual(d1, 0.05, accuracy: 0.001)
        XCTAssertEqual(d2, 0.10, accuracy: 0.001)
    }

    func testBatchResetAfterInterval() throws {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let c0 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        entrance.handle(cell: c0, indexPath: IndexPath(item: 0, section: 0))

        // 等 > batchInterval(50ms)，新批 batchIndex 归 0
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let c1 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 1, section: 0))
        entrance.handle(cell: c1, indexPath: IndexPath(item: 1, section: 0))
        let d1 = try XCTUnwrap(entrance.animating[ObjectIdentifier(c1.contentView)]?.delay)
        XCTAssertEqual(d1, 0, accuracy: 0.001)
    }

    func testCellReuseRestartsAnimation() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        let contentView = cell.contentView

        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        // 同一 contentView 复用给新 indexPath，应重置动画
        entrance.handle(cell: cell, indexPath: IndexPath(item: 5, section: 0))
        let secondState = entrance.animating[ObjectIdentifier(contentView)]
        XCTAssertNotNil(secondState)
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5, "复用后回到初始态")
        XCTAssertTrue(entrance.displayedIndexPaths.contains(IndexPath(item: 5, section: 0)))
    }

    func testAnimationCompletesToIdentity() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.05, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        let exp = expectation(description: "animation done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        // CGAffineTransform 不支持 accuracy 整体比较，按分量断言
        XCTAssertEqual(cell.contentView.transform.tx, 0, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.transform.ty, 0, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.transform.a, 1, accuracy: 0.05)
        XCTAssertEqual(cell.contentView.transform.d, 1, accuracy: 0.05)
        XCTAssertEqual(cell.contentView.alpha, 1, accuracy: 0.05)
        XCTAssertTrue(entrance.animating.isEmpty, "完成后应移出 animating")
    }

    func testEntranceDeallocatesAfterScrollViewReleased() {
        weak var weakEntrance: ListEffectEntrance?
        autoreleasepool {
            let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
            cv.entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
            cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
            cv.entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))  // 启动 displayLink
            weakEntrance = cv.entrance
            XCTAssertNotNil(weakEntrance)
        }
        XCTAssertNil(weakEntrance, "entrance 泄漏 — displayLink 强引用循环？")
    }
}
#endif
