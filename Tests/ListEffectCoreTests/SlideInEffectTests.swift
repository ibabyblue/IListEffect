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
        // easeOut: t = 1 - (1-0.5)^3 = 0.875 → x = 100*(1-0.875) = 12.5
        XCTAssertEqual(out.translation.x, 12.5, accuracy: 0.5)
        XCTAssertEqual(out.alpha, 0.875, accuracy: 0.001)
    }

    func testEaseOutBackOvershootsMidway() {
        let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: .easeOutBack)
        let mid = e.resolve(progress: 0.5)
        // easeOutBack 中段 t > 1（回弹），故 alpha > 1、x < 0
        XCTAssertGreaterThan(mid.alpha, 1.0)
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
        XCTAssertEqual(e.timing, .easeOutBack)
    }
}
