// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "IListEffect",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "ListEffect-Core", targets: ["ListEffectCore"]),
    ],
    targets: [
        .target(name: "ListEffectCore"),
        .testTarget(name: "ListEffectCoreTests", dependencies: ["ListEffectCore"]),
    ]
)
