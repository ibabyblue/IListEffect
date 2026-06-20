// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "IListEffect",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "ListEffect-Core", targets: ["ListEffectCore"]),
        .library(name: "ListEffect-UIKit", targets: ["ListEffectUIKit"]),
    ],
    targets: [
        .target(name: "ListEffectCore"),
        .target(name: "ListEffectUIKit", dependencies: ["ListEffectCore"]),
        .testTarget(name: "ListEffectCoreTests", dependencies: ["ListEffectCore"]),
        .testTarget(name: "ListEffectUIKitTests", dependencies: ["ListEffectUIKit"]),
    ]
)
