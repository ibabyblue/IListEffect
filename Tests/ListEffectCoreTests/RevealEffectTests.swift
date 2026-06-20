import XCTest
@testable import ListEffectCore

final class RevealEffectTests: XCTestCase {
    func testCenterFullyRevealed() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 0)
        XCTAssertEqual(out.scale, 1, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 1, accuracy: 0.001)
    }

    func testEdgeMinScaleZeroAlpha() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 1)
        XCTAssertEqual(out.scale, 0.8, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0, accuracy: 0.001)
    }

    func testHalfwayInterpolates() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 0.5)
        XCTAssertEqual(out.scale, 0.9, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0.5, accuracy: 0.001)
    }

    func testBeyondEdgeClampsToMin() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 2)
        XCTAssertEqual(out.scale, 0.8, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0, accuracy: 0.001)
    }
}
