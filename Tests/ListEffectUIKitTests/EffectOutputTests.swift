#if canImport(UIKit)
import XCTest
import UIKit
import CoreGraphics
import ListEffectCore
@testable import ListEffectUIKit

final class UIKitEffectOutputTests: XCTestCase {
    private func makeView() -> UIView { UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)) }

    func test2DRotationUsesAffineTransform() {
        let v = makeView()
        applyEffectOutput(EffectOutput(rotation: .pi / 2, rotationAxis: .z), to: v)
        // view.transform 与 layer.transform 共享存储；2D 通道仅写仿射、不注入透视（m34==0）
        XCTAssertEqual(v.layer.transform.m34, 0, "2D 通道不应注入 3D 透视")
        XCTAssertNotEqual(v.transform, .identity, "2D 旋转应写入 view.transform")
        XCTAssertEqual(v.transform.b, 1, accuracy: 0.0001, "π/2 旋转应体现为仿射矩阵 b 分量")
    }

    func test3DRotationWritesLayerTransformWithPerspective() {
        let v = makeView()
        applyEffectOutput(EffectOutput(rotation: 0.5, rotationAxis: .x, perspective: -0.002), to: v)
        XCTAssertFalse(CATransform3DIsIdentity(v.layer.transform), "3D 旋转应写入 layer.transform")
        XCTAssertEqual(v.transform, .identity, "3D 旋转应清空 view.transform")
        XCTAssertEqual(v.layer.transform.m34, -0.002, accuracy: 0.0001)
    }

    func testAnchorPointAppliedWhenNotCenter() {
        let v = makeView()
        applyEffectOutput(EffectOutput(anchor: AnchorPoint(x: 0, y: 0)), to: v)
        XCTAssertEqual(v.layer.anchorPoint, CGPoint(x: 0, y: 0))
    }

    func testAnchorPointNotChangedAtCenter() {
        let v = makeView()
        v.layer.anchorPoint = CGPoint(x: 0.3, y: 0.3)
        applyEffectOutput(EffectOutput(anchor: .center), to: v)
        XCTAssertEqual(v.layer.anchorPoint, CGPoint(x: 0.3, y: 0.3), "center 不应改写已有 anchorPoint")
    }
}
#endif
