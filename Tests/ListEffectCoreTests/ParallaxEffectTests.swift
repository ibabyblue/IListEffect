import XCTest
@testable import ListEffectCore

final class ParallaxEffectTests: XCTestCase {
    func testEffectOutputDefaults() {
        let out = EffectOutput()
        XCTAssertEqual(out.translation, .zero)
        XCTAssertEqual(out.scale, 1)
        XCTAssertEqual(out.rotation, 0)
        XCTAssertEqual(out.alpha, 1)
    }

    func testCenterHasNoOffset() {
        let out = ParallaxEffect(amplitude: 24).resolve(position: 0)
        XCTAssertEqual(out.translation.y, 0, accuracy: 0.001)
    }

    func testBottomEdgeFullAmplitude() {
        let out = ParallaxEffect(amplitude: 24).resolve(position: 1)
        XCTAssertEqual(out.translation.y, 24, accuracy: 0.001)
    }

    func testTopHalfNegativeHalfAmplitude() {
        let out = ParallaxEffect(amplitude: 24).resolve(position: -0.5)
        XCTAssertEqual(out.translation.y, -12, accuracy: 0.001)
    }
}
