import XCTest
import CoreGraphics
@testable import ListEffectCore

final class SlideInEffectTests: XCTestCase {
    func testProgress0IsInitialOffset() {
        let e = SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut)
        let out = e.resolve(progress: 0)
        XCTAssertEqual(out.translation.x, 220, accuracy: 0.5)
        XCTAssertEqual(out.translation.y, 0, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0, accuracy: 0.001)
    }

    func testProgress1IsIdentity() {
        let e = SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut)
        let out = e.resolve(progress: 1)
        XCTAssertEqual(out.translation.x, 0, accuracy: 0.5)
        XCTAssertEqual(out.alpha, 1, accuracy: 0.001)
    }

    func testProgressHalfIsMidway() {
        let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: .easeOut)
        let out = e.resolve(progress: 0.5)
        // translation 用 timing：easeOut t = 1 - (1-0.5)^3 = 0.875 → x = 100*(1-0.875) = 12.5
        XCTAssertEqual(out.translation.x, 12.5, accuracy: 0.5)
        // alpha 前 1/3 即满：progress 0.5 → min(1, 0.5*3) = 1
        XCTAssertEqual(out.alpha, 1.0, accuracy: 0.001)
    }

    func testEaseOutBackOvershootsMidway() {
        let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: .easeOutBack)
        let mid = e.resolve(progress: 0.5)
        // alpha 前 1/3 已满（不再随 timing 回弹到 >1）
        XCTAssertEqual(mid.alpha, 1.0, accuracy: 0.001)
        // translation 仍随 timing 回弹（t>1 → x<0）
        XCTAssertLessThan(mid.translation.x, 0)
    }

    func testTimingEndpoints() {
        for timing in [SlideInEffect.Timing.easeOut, .easeInOut, .easeOutBack] {
            let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: timing)
            XCTAssertEqual(e.resolve(progress: 0).alpha, 0, accuracy: 0.001)
            XCTAssertEqual(e.resolve(progress: 1).alpha, 1, accuracy: 0.001)
        }
    }

    func testDefaults() {
        let e = SlideInEffect()
        XCTAssertEqual(e.amplitude, 220)
        XCTAssertEqual(e.duration, 0.5)
        XCTAssertEqual(e.timing, .easeOut)
    }

    /// Bug1 回归：滑入早期 alpha 必须已快速变满，否则横向位移在 cell 不可见时就走完，看不到滑入。
    func testAlphaSaturatesEarlyForVisibleSlide() {
        let e = SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOutBack)
        // progress 0.2 时 alpha 应已满（前 ~1/5 即满），此时 translation 仍有明显横向偏移
        let early = e.resolve(progress: 0.2)
        XCTAssertEqual(early.alpha, 1.0, accuracy: 0.001, "前 20% 进度 alpha 应满，保证滑入可见")
        XCTAssertGreaterThan(early.translation.x, 1.0, "alpha 满时 translation 仍应有可见横向偏移")
        // 极早期（progress 0.05）alpha 仍在淡入中
        XCTAssertLessThan(e.resolve(progress: 0.05).alpha, 1.0)
    }

    func testSpringEndpoints() {
        let t = SlideInEffect.Timing.spring(damping: 0.5, frequency: 1.0)
        XCTAssertEqual(t.apply(to: 0), 0, accuracy: 0.001)
        XCTAssertEqual(t.apply(to: 1), 1, accuracy: 0.05, "spring 在 progress=1 应收敛到 1")
    }

    func testSpringResolveCompletesExactlyAtIdentity() {
        let e = SlideInEffect(amplitude: 220, duration: 0.5, timing: .spring(damping: 0.5, frequency: 1.0))
        let out = e.resolve(progress: 1)
        XCTAssertEqual(out.translation.x, 0, accuracy: 0.001, "spring 完成帧必须精确归位，避免驱动器移除动画后残留偏移")
        XCTAssertEqual(out.alpha, 1, accuracy: 0.001)
    }

    func testSpringOvershoots() {
        let t = SlideInEffect.Timing.spring(damping: 0.3, frequency: 1.2)
        // 中段应存在回弹（>1）
        let values = stride(from: 0.0, through: 1.0, by: 0.05).map { t.apply(to: CGFloat($0)) }
        XCTAssertTrue(values.contains(where: { $0 > 1.0 }), "欠阻尼 spring 应出现超调")
    }
}
