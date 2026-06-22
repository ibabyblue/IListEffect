import XCTest
import CoreGraphics
@testable import ListEffectCore

final class EntranceEffectTests: XCTestCase {
    func testCanConformToEntranceEffect() {
        struct Dummy: EntranceEffect {
            var duration: TimeInterval { 0.5 }
            func resolve(progress: CGFloat) -> EffectOutput { EffectOutput() }
        }
        let d = Dummy()
        XCTAssertEqual(d.duration, 0.5)
        XCTAssertEqual(d.resolve(progress: 1).alpha, 1)
    }
}
