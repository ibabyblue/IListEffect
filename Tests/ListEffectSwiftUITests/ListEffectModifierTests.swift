#if canImport(SwiftUI)
import XCTest
import SwiftUI
import ListEffectCore
@testable import ListEffectSwiftUI

final class ListEffectModifierTests: XCTestCase {
    func testModifierBuildsWithPositionEffect() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            throw XCTSkip("listEffect 需要 iOS 17 / macOS 14")
        }
        // smoke：构造加了 modifier 的视图不应崩溃/编译失败；真实视觉靠 demo 目测。
        // 用 AnyView 强制对视图求值一次，确保 body 能被构造。
        let wrapped = AnyView(Text("row").listEffect(RevealEffect(minScale: 0.8)))
        _ = wrapped
    }

    func testListEffectBuildsWith3DAxis() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else { throw XCTSkip("需要 iOS 17 / macOS 14") }
        struct Tilt: PositionEffect {
            func resolve(position: CGFloat) -> EffectOutput {
                EffectOutput(rotation: position * 0.5, rotationAxis: .x, perspective: -0.002)
            }
        }
        let wrapped = AnyView(Text("row").listEffect(Tilt()))
        _ = wrapped  // smoke：构造不崩溃
    }
}
#endif
