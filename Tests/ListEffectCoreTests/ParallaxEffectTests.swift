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
}
