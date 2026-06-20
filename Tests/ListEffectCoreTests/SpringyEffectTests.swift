import XCTest
@testable import ListEffectCore

final class SpringyEffectTests: XCTestCase {
    // 距离恰等于 stiffness 时 resistance==1，dy 不被裁剪，等于 delta
    func testResistanceOneKeepsFullDelta() {
        let effect = SpringyEffect(stiffness: 2400)
        let out = effect.resolve(delta: 10,
                                 itemCenter: CGPoint(x: 0, y: 2400),
                                 touch: .zero,
                                 container: CGSize(width: 320, height: 480))
        XCTAssertEqual(out.translation.y, 10, accuracy: 0.001)
    }

    // 距离为 stiffness 的一半时 resistance==0.5，dy 被裁剪到 delta 的一半
    func testCloserItemLagsBehind() {
        let effect = SpringyEffect(stiffness: 2400)
        let out = effect.resolve(delta: 10,
                                 itemCenter: CGPoint(x: 0, y: 1200),
                                 touch: .zero,
                                 container: CGSize(width: 320, height: 480))
        XCTAssertEqual(out.translation.y, 5, accuracy: 0.001)
    }

    // 负向滚动同样被裁剪
    func testNegativeDeltaClampedTowardZero() {
        let effect = SpringyEffect(stiffness: 2400)
        let out = effect.resolve(delta: -10,
                                 itemCenter: CGPoint(x: 0, y: 1200),
                                 touch: .zero,
                                 container: CGSize(width: 320, height: 480))
        XCTAssertEqual(out.translation.y, -5, accuracy: 0.001)
    }

    // 远距离 resistance>1，dy 仍被裁剪到 delta（不超过滚动量）
    func testFarItemCappedAtDelta() {
        let effect = SpringyEffect(stiffness: 2400)
        let out = effect.resolve(delta: 10,
                                 itemCenter: CGPoint(x: 0, y: 7200),
                                 touch: .zero,
                                 container: CGSize(width: 320, height: 480))
        XCTAssertEqual(out.translation.y, 10, accuracy: 0.001)
    }
}
