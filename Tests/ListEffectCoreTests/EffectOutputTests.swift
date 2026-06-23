import XCTest
import CoreGraphics
@testable import ListEffectCore

final class EffectOutputTests: XCTestCase {
    func testDefaultsAreNil() {
        let out = EffectOutput()
        XCTAssertNil(out.rotationAxis)
        XCTAssertNil(out.perspective)
        XCTAssertNil(out.anchor)
        XCTAssertEqual(out.scale, 1)
        XCTAssertEqual(out.alpha, 1)
    }

    func testRotationAxisPresets() {
        XCTAssertEqual(RotationAxis.z, RotationAxis(x: 0, y: 0, z: 1))
        XCTAssertEqual(RotationAxis.x, RotationAxis(x: 1, y: 0, z: 0))
    }

    func testAnchorPointCenter() {
        XCTAssertEqual(AnchorPoint.center, AnchorPoint(x: 0.5, y: 0.5))
    }

    func testInitPreservesNewFields() {
        let out = EffectOutput(rotation: 0.5, rotationAxis: .x, perspective: -0.002, anchor: AnchorPoint(x: 0, y: 0))
        XCTAssertEqual(out.rotationAxis, .x)
        XCTAssertEqual(out.perspective ?? 0, -0.002, accuracy: 0.0001)
        XCTAssertEqual(out.anchor, AnchorPoint(x: 0, y: 0))
    }
}
