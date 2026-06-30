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

    func testAnchorPointRestoresToCenter() {
        let v = makeView()
        v.layer.anchorPoint = CGPoint(x: 0.3, y: 0.3)
        applyEffectOutput(EffectOutput(anchor: .center), to: v)
        XCTAssertEqual(v.layer.anchorPoint, CGPoint(x: 0.5, y: 0.5), "center 应恢复默认 anchorPoint，避免复用时泄漏")
    }

    func testAnchorPointChangePreservesFrame() {
        let v = makeView()
        let frame = v.frame
        applyEffectOutput(EffectOutput(anchor: AnchorPoint(x: 0, y: 0)), to: v)
        XCTAssertEqual(v.frame.origin.x, frame.origin.x, accuracy: 0.001)
        XCTAssertEqual(v.frame.origin.y, frame.origin.y, accuracy: 0.001)
        XCTAssertEqual(v.frame.size.width, frame.size.width, accuracy: 0.001)
        XCTAssertEqual(v.frame.size.height, frame.size.height, accuracy: 0.001)
    }

    /// 3D→2D 通道切换：2D 通道写 view.transform，其 setter 写入 CATransform3DMakeAffineTransform(仿射)，
    /// 该 3D 矩阵 m34 恒为 0，必然覆盖 3D 通道遗留的 layer.transform.m34 透视。
    /// 推演：view.transform setter 后 layer.transform = MakeAffineTransform(translation 10,0)，
    /// 是非 identity 仿射的 3D 投影，因此 **不** 断言 CATransform3DIsIdentity，只锁定无 m34 残留 + 仿射正确。
    func test3DTo2DChannelSwitchNoPerspectiveResidue() {
        let v = makeView()
        // 3D 通道：写 layer.transform，含 m34 = -0.002
        applyEffectOutput(EffectOutput(rotation: 0.5, rotationAxis: .x, perspective: -0.002), to: v)
        XCTAssertEqual(v.layer.transform.m34, -0.002, accuracy: 0.0001, "前置：3D 通道应注入透视")
        // 2D 通道：写 view.transform（底层覆盖 layer.transform，m34 归零）
        applyEffectOutput(EffectOutput(translation: CGPoint(x: 10, y: 0), rotation: 0, rotationAxis: .z), to: v)
        XCTAssertEqual(v.layer.transform.m34, 0, "2D 通道应清掉 3D 透视残留")
        XCTAssertEqual(v.transform.tx, 10, "2D 仿射应正确写入")
    }
}
#endif
