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
        XCTAssertEqual(cell.transform.tx, 220, accuracy: 0.5)
        XCTAssertEqual(cell.alpha, 0, accuracy: 0.001)
    }

    /// 回归：变换必须施加在 **cell 本身**，不能在 cell.contentView。
    /// UITableViewCell/UICollectionViewCell 会每次布局复位 contentView.transform，
    /// 写到 contentView 上的变换在屏幕上完全不可见（曾导致 SlideIn/Reveal 看不出位移）。
    func testTransformsCellNotContentView() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cell = makeCell()
        entrance.prepare(cell: cell)
        XCTAssertEqual(cell.transform.tx, 220, accuracy: 0.5, "应变换 cell 本身")
        XCTAssertEqual(cell.contentView.transform.tx, 0, accuracy: 0.5,
                       "不应变换 contentView（会被 cell 布局复位、屏幕上不可见）")
    }

    func testPrepareWithoutAttachIsNoOp() {
        let entrance = ListEffectEntrance()  // 未 attach
        let cell = makeCell()
        let alphaBefore = cell.alpha
        entrance.prepare(cell: cell)
        // 未 attach 时 prepare 应为 no-op：不改变 cell 的既有 transform/alpha
        XCTAssertEqual(cell.transform, .identity)
        XCTAssertEqual(cell.alpha, alphaBefore, accuracy: 0.001)
    }

    func testHandleWithoutAttachIsNoOp() {
        let entrance = ListEffectEntrance()  // 未 attach
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        XCTAssertEqual(cell.transform, .identity)
        XCTAssertTrue(entrance.animating.isEmpty)
    }

    func testHandleRecordsAnimatingAndDisplayed() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        let ip = IndexPath(item: 0, section: 0)
        entrance.handle(cell: cell, indexPath: ip)
        XCTAssertTrue(entrance.displayedIndexPaths.contains(ip))
        XCTAssertFalse(entrance.animating.isEmpty, "handle 后应标记动画中")
    }

    func testRedisplayDoesNotAnimate() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        let ip = IndexPath(item: 0, section: 0)
        entrance.handle(cell: cell, indexPath: ip)   // 首次
        entrance.handle(cell: cell, indexPath: ip)   // 回滑
        XCTAssertEqual(cell.transform, .identity)
        XCTAssertEqual(cell.alpha, 1, accuracy: 0.001)
        XCTAssertNil(entrance.animating[ObjectIdentifier(cell)], "回滑后应无进行中动画")
    }

    func testCellReuseRestartsAnimation() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        // 同一 contentView 复用给新 indexPath，应重新入场
        entrance.handle(cell: cell, indexPath: IndexPath(item: 5, section: 0))
        XCTAssertTrue(entrance.displayedIndexPaths.contains(IndexPath(item: 5, section: 0)))
        XCTAssertNotNil(entrance.animating[ObjectIdentifier(cell)], "复用后应重新标记动画中")
    }

    func testAnimationCompletesAndClears() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.05, timing: .easeOut))
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        let exp = expectation(description: "animation done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(cell.transform.tx, 0, accuracy: 0.5)
        XCTAssertEqual(cell.transform.ty, 0, accuracy: 0.5)
        XCTAssertEqual(cell.alpha, 1, accuracy: 0.05)
        XCTAssertNil(entrance.animating[ObjectIdentifier(cell)], "完成后应移出 animating")
    }

    func testTickAdvancesProgressAndAppliesIntermediateFrame() {
        let entrance = ListEffectEntrance()
        let amplitude: CGFloat = 220
        let duration = 0.5
        entrance.attach(SlideInEffect(amplitude: amplitude, duration: duration, timing: .easeOut))
        entrance.clock = { 1000.0 }
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        let id = IndexPath(item: 0, section: 0)
        entrance.handle(cell: cell, indexPath: id)

        // 起始帧：初始态（右偏 220、alpha 0）
        entrance.tick(at: 1000.0)
        XCTAssertEqual(cell.transform.tx, amplitude, accuracy: 1.0)

        // 中间帧（progress 0.5）：easeOut → t=0.875 → x=amplitude*(1-0.875)
        // 验证 timing 真正被采样（修复点）
        entrance.tick(at: 1000.0 + duration / 2)
        XCTAssertEqual(cell.transform.tx, amplitude * (1 - 0.875), accuracy: 2.0)
    }

    func testTickAtCompletionClearsAnimation() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.05, timing: .easeOut))
        entrance.clock = { 2000.0 }
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        entrance.tick(at: 2000.0 + 0.1)  // 超过 duration

        XCTAssertEqual(cell.transform.tx, 0, accuracy: 1.0)
        XCTAssertEqual(cell.alpha, 1, accuracy: 0.05)
        XCTAssertNil(entrance.animating[ObjectIdentifier(cell)])
    }

    func testHandleFallbackAppliesInitialState() {
        // 漏调 prepare：handle 启动时自带兜底设初始态，不闪
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        entrance.clock = { 3000.0 }
        entrance.animateInitialBatch([])  // 标记首批已过，handle 进入正常滚动路径
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        entrance.tick(at: 3000.0)
        XCTAssertEqual(cell.transform.tx, 220, accuracy: 1.0)
        XCTAssertEqual(cell.alpha, 0, accuracy: 0.001)
    }

    func testAnimateInitialBatchIsIdempotent() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        entrance.clock = { 4000.0 }
        let cell1 = makeCell(), cell2 = makeCell()
        let cells: [(view: UIView, indexPath: IndexPath)] = [
            (cell1, IndexPath(item: 0, section: 0)),
            (cell2, IndexPath(item: 1, section: 0)),
        ]
        entrance.animateInitialBatch(cells)
        XCTAssertEqual(entrance.animating.count, 2)
        entrance.animating.removeAll()  // 模拟首批已结束
        entrance.animateInitialBatch(cells)  // 二次：应 no-op
        XCTAssertTrue(entrance.animating.isEmpty, "二次调用不应再次动画")
    }

    func testAnimateInitialBatchAppliesStaggeredDelays() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        entrance.clock = { 5000.0 }
        let cell0 = makeCell(), cell1 = makeCell()
        let cells: [(view: UIView, indexPath: IndexPath)] = [
            (cell0, IndexPath(item: 0, section: 0)),
            (cell1, IndexPath(item: 1, section: 0)),
        ]
        entrance.animateInitialBatch(cells)
        let start0 = entrance.animating[ObjectIdentifier(cell0)]!.start
        let start1 = entrance.animating[ObjectIdentifier(cell1)]!.start
        XCTAssertEqual(start1 - start0, entrance.perRowDelay, accuracy: 0.001, "第 1 行应错开 perRowDelay")
    }

    func testHandleNoOpBeforeInitialBatch() {
        // 首批前 handle 应 no-op，等 animateInitialBatch 统一处理
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cell = makeCell()
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        XCTAssertTrue(entrance.animating.isEmpty, "initialBatchTriggered 前应 no-op")
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
