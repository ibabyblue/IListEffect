#if canImport(SwiftUI)
import XCTest
import SwiftUI
import ListEffectCore
@testable import ListEffectSwiftUI

final class ListEffectModifierTests: XCTestCase {
    func testModifierBuildsWithPositionEffect() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            throw XCTSkip("listEffect 需要 iOS 17 / macOS 14")
        }
        // smoke：构造加了 modifier 的视图不应崩溃/编译失败；真实视觉靠 demo 目测。
        // 用 AnyView 强制对视图求值一次，确保 body 能被构造。
        let wrapped = AnyView(Text("row").listEffect(RevealEffect(minScale: 0.8)))
        _ = wrapped
    }

    func testListEffectBuildsWith3DAxis() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        struct Tilt: PositionEffect {
            func resolve(position: CGFloat) -> EffectOutput {
                EffectOutput(rotation: position * 0.5, rotationAxis: .x, perspective: -0.002)
            }
        }
        let wrapped = AnyView(Text("row").listEffect(Tilt()))
        _ = wrapped  // smoke：构造不崩溃
    }

    func testEntranceEffectBuilds() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let wrapped = AnyView(Text("row").entranceEffect(SlideInEffect()))
        _ = wrapped  // smoke：构造不崩溃
    }

    func testEntranceEffectWithStaggerIndexBuilds() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let wrapped = AnyView(Text("row").entranceEffect(SlideInEffect(), index: 3))
        _ = wrapped  // smoke：带 stagger index 的重载构造不崩溃
    }

    func testEntranceEffectWithStableIDBuilds() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let wrapped = AnyView(Text("row").entranceEffect(SlideInEffect(), id: "item-1"))
        _ = wrapped
    }

    func testListEntranceContainerBuilds() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let wrapped = AnyView(
            ScrollView { Text("row").entranceEffect(SlideInEffect(), index: 0) }.listEntrance()
        )
        _ = wrapped  // smoke：容器 + row 组合构造不崩溃
    }

    // MARK: - 入场协调器逻辑（纯逻辑，确定性）

    func testCoordinatorLatchesEntranceOnce() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let c = EntranceCoordinator(perRowDelay: 0.05, delayRowCap: 12)
        XCTAssertFalse(c.hasEntered(0))
        XCTAssertNotNil(c.registerEntrance(index: 0), "首次入场应返回延迟")
        XCTAssertTrue(c.hasEntered(0))
        XCTAssertNil(c.registerEntrance(index: 0), "再次入场应返回 nil（不重播）")
    }

    func testCoordinatorLatchesStableIdentityOnce() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let c = EntranceCoordinator(perRowDelay: 0.05, delayRowCap: 12)
        XCTAssertFalse(c.hasEntered(id: "item-1"))
        XCTAssertNotNil(c.registerEntrance(id: "item-1"))
        XCTAssertTrue(c.hasEntered(id: "item-1"))
        XCTAssertNil(c.registerEntrance(id: "item-1"))
    }

    func testCoordinatorResetAllowsStableIdentityToEnterAgain() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let c = EntranceCoordinator(perRowDelay: 0.05, delayRowCap: 12)
        XCTAssertNotNil(c.registerEntrance(id: "item-1"))
        c.resetEnteredState()
        XCTAssertNotNil(c.registerEntrance(id: "item-1"))
    }

    func testCoordinatorStaggersInitialBatchByArrivalOrder() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let c = EntranceCoordinator(perRowDelay: 0.05, delayRowCap: 12)
        XCTAssertEqual(try XCTUnwrap(c.registerEntrance(index: 7)), 0.0, accuracy: 1e-9, "首批第 0 个到达，delay 0")
        XCTAssertEqual(try XCTUnwrap(c.registerEntrance(index: 3)), 0.05, accuracy: 1e-9, "首批第 1 个到达，delay perRowDelay")
        XCTAssertEqual(try XCTUnwrap(c.registerEntrance(index: 9)), 0.10, accuracy: 1e-9, "首批第 2 个到达，delay 2*perRowDelay")
    }

    func testCoordinatorNoStaggerAfterInitialBatchClosed() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let c = EntranceCoordinator(perRowDelay: 0.05, delayRowCap: 12)
        c.closeInitialBatch()
        XCTAssertEqual(try XCTUnwrap(c.registerEntrance(index: 30)), 0.0, accuracy: 1e-9, "首批关闭后滚动进入者 delay 0")
    }

    func testCoordinatorCapsStaggerDelay() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        let c = EntranceCoordinator(perRowDelay: 0.05, delayRowCap: 2)
        _ = c.registerEntrance(index: 0)   // order 0 → 0
        _ = c.registerEntrance(index: 1)   // order 1 → 0.05
        _ = c.registerEntrance(index: 2)   // order 2 → 0.10 (cap=2)
        XCTAssertEqual(try XCTUnwrap(c.registerEntrance(index: 3)), 0.10, accuracy: 1e-9, "order 超过 cap 后延迟封顶")
    }

    func testRowVisibilityPredicate() {
        // 视口高 600；命名坐标系中 minY 为相对视口顶部的位置。
        XCTAssertFalse(entranceRowIsVisible(rowMinY: 100, rowMaxY: 180, viewportHeight: 0), "视口未知 → 不可见")
        XCTAssertTrue(entranceRowIsVisible(rowMinY: 100, rowMaxY: 180, viewportHeight: 600), "完全在视口内")
        XCTAssertTrue(entranceRowIsVisible(rowMinY: 580, rowMaxY: 660, viewportHeight: 600), "顶部刚越过底边 → 可见")
        XCTAssertFalse(entranceRowIsVisible(rowMinY: 600, rowMaxY: 680, viewportHeight: 600), "完全在视口下方 → 不可见")
        XCTAssertFalse(entranceRowIsVisible(rowMinY: -120, rowMaxY: 0, viewportHeight: 600), "完全在视口上方 → 不可见")
    }

    func testEntranceOutputSamplesEffectProgress() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        struct VerticalEntrance: EntranceEffect {
            var duration: TimeInterval { 0.5 }
            func resolve(progress: CGFloat) -> EffectOutput {
                EffectOutput(translation: CGPoint(x: 0, y: 100 * (1 - progress)), alpha: progress)
            }
        }
        let out = entranceOutput(for: VerticalEntrance(), progress: 0.25)
        XCTAssertEqual(out.translation.y, 75, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0.25, accuracy: 0.001)
    }
}
#endif
