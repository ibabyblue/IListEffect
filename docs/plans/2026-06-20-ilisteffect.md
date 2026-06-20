# IListEffect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一个 SPM 库，为可滚动列表（UIKit `UITableView`/`UICollectionView` 与 SwiftUI）施加与滚动关联的动画效果，首发"弹性跟随"，并为后续扩展更多效果留好口子。

**Architecture:** 三层 target——`ListEffectCore`（零 UI 依赖的纯传递函数）+ `ListEffectUIKit`（基于 `UIScrollView` + KVO + cell transform 的适配，覆盖 Table/Collection）+ `ListEffectSwiftUI`（基于 `.scrollTransition` 的 ViewModifier，iOS 17+）。核心抽象拆成 `PositionEffect`（双端）与 `TrackingEffect`（UIKit 专属）两个协议，让跨端能力差异由类型系统强制表达。

**Tech Stack:** Swift 5.10, Swift Package Manager, XCTest, UIKit, SwiftUI, CoreGraphics, XcodeGen（demo）。

## Global Constraints

- swift-tools-version: 5.10
- 平台：iOS 15 / macOS 12（包级），SwiftUI 滚动效果 API 用 `@available(iOS 17, *)` / `@available(macOS 14, *)` gate
- 包名 `IListEffect`；target 名 `ListEffectCore` / `ListEffectUIKit` / `ListEffectSwiftUI`；product 名 `ListEffect-Core` / `ListEffect-UIKit` / `ListEffect-SwiftUI`
- `ListEffectCore` 禁止 import UIKit / SwiftUI（仅 Foundation / CoreGraphics）
- UIKit 代码一律用 `#if canImport(UIKit)` 包裹（兼容包级 macOS 声明）
- 库接管 cell 的 `transform` / `layer.transform` / `alpha`，文档需明示
- 提交信息单行 subject，无 body，无 `Co-Authored-By`
- **测试运行方式**：Core（Task 1–4）用 `swift test`。UIKit / SwiftUI（Task 5–8）的代码被 `#if canImport(UIKit/SwiftUI)` 包裹，在 macOS host 上 `swift test` 会把它们编译为空、测试不运行；这些 target 必须跑 iOS 模拟器：
  `xcodebuild test -scheme IListEffect-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:<TestTarget>/<TestClass>`
  （注：声明多 target 后 SPM 的整包 scheme 名为 `IListEffect-Package`。）
  （RED 步骤表现为编译失败而非断言失败。各 Task 步骤里写的 `swift test --filter ...` 对 UIKit/SwiftUI 一律以本命令为准。）

---

## File Structure

```
IListEffect/
├── Package.swift
├── Sources/
│   ├── ListEffectCore/
│   │   ├── EffectOutput.swift          两端共用输出结构
│   │   ├── PositionEffect.swift        位置型协议
│   │   ├── TrackingEffect.swift        跟随型协议
│   │   ├── SpringyEffect.swift         TrackingEffect 实现
│   │   ├── ParallaxEffect.swift        PositionEffect 实现
│   │   └── RevealEffect.swift          PositionEffect 实现
│   ├── ListEffectUIKit/
│   │   ├── ListEffectHost.swift        宿主协议 + Table/Collection 适配
│   │   ├── ListEffectController.swift  KVO 驱动 + transform 应用 + 归位
│   │   └── UIScrollView+ListEffect.swift  associated-object 命名空间
│   └── ListEffectSwiftUI/
│       └── View+ListEffect.swift       ViewModifier（iOS 17+）
├── Tests/
│   ├── ListEffectCoreTests/
│   │   ├── SpringyEffectTests.swift
│   │   ├── ParallaxEffectTests.swift
│   │   └── RevealEffectTests.swift
│   ├── ListEffectUIKitTests/
│   │   ├── ListEffectHostTests.swift
│   │   └── ListEffectControllerTests.swift
│   └── ListEffectSwiftUITests/
│       └── ListEffectModifierTests.swift
└── demo/
    ├── project.yml
    └── IListEffectDemo/...
```

---

### Task 1: 包脚手架 + Core 输出结构与两个协议

**Files:**
- Create: `Package.swift`
- Create: `Sources/ListEffectCore/EffectOutput.swift`
- Create: `Sources/ListEffectCore/PositionEffect.swift`
- Create: `Sources/ListEffectCore/TrackingEffect.swift`
- Test: `Tests/ListEffectCoreTests/ParallaxEffectTests.swift`（本任务先放占位测试验证编译，Task 3 填充）

**Interfaces:**
- Produces:
  - `struct EffectOutput: Equatable`，成员 `translation: CGPoint`、`scale: CGFloat`、`rotation: CGFloat`、`alpha: CGFloat`；`init(translation:scale:rotation:alpha:)` 全部带默认值（`.zero / 1 / 0 / 1`）
  - `protocol PositionEffect { func resolve(position: CGFloat) -> EffectOutput }`
  - `protocol TrackingEffect { func resolve(delta: CGFloat, itemCenter: CGPoint, touch: CGPoint, container: CGSize) -> EffectOutput }`

- [ ] **Step 1: 写 Package.swift**

```swift
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
```

> **注（构建正确性）**：SPM 不允许 target 目录为空。`ListEffectUIKit` / `ListEffectSwiftUI` 的 target、product 与对应 test target **不在此处声明**，而是等到它们第一个源文件落地时再加入 Package.swift——UIKit 在 Task 5，SwiftUI 在 Task 8。如此每个 commit 都能独立构建，无需占位文件。

- [ ] **Step 2: 写 EffectOutput.swift**

```swift
import CoreGraphics

/// 效果的输出，UIKit 与 SwiftUI 两端共用。
public struct EffectOutput: Equatable {
    public var translation: CGPoint
    public var scale: CGFloat
    /// 旋转弧度，用于 2D/3D 旋转。
    public var rotation: CGFloat
    public var alpha: CGFloat

    public init(translation: CGPoint = .zero,
                scale: CGFloat = 1,
                rotation: CGFloat = 0,
                alpha: CGFloat = 1) {
        self.translation = translation
        self.scale = scale
        self.rotation = rotation
        self.alpha = alpha
    }
}
```

- [ ] **Step 3: 写 PositionEffect.swift**

```swift
import CoreGraphics

/// 位置型效果：输入归一化位置（-1 顶部外 … 0 居中 … 1 底部外），UIKit / SwiftUI 双端均可实现。
public protocol PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput
}
```

- [ ] **Step 4: 写 TrackingEffect.swift**

```swift
import CoreGraphics

/// 跟随型效果：依赖触摸位置与每帧位移，UIKit 专属。
/// `delta`：本帧滚动位移；`itemCenter`：cell 静止中心；`touch`：手指位置；`container`：滚动容器尺寸。
public protocol TrackingEffect {
    func resolve(delta: CGFloat,
                 itemCenter: CGPoint,
                 touch: CGPoint,
                 container: CGSize) -> EffectOutput
}
```

- [ ] **Step 5: 写占位测试验证编译**

`Tests/ListEffectCoreTests/ParallaxEffectTests.swift`:

```swift
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
```

- [ ] **Step 6: 运行测试，确认通过**

Run: `swift test --filter ListEffectCoreTests`
Expected: PASS（1 个测试）

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/ListEffectCore Tests/ListEffectCoreTests
git commit -m "feat(core): scaffold package with EffectOutput and effect protocols"
```

---

### Task 2: SpringyEffect（TrackingEffect）

**Files:**
- Create: `Sources/ListEffectCore/SpringyEffect.swift`
- Test: `Tests/ListEffectCoreTests/SpringyEffectTests.swift`

**Interfaces:**
- Consumes: `EffectOutput`、`TrackingEffect`（Task 1）
- Produces: `struct SpringyEffect: TrackingEffect`，属性 `stiffness: CGFloat`（默认 `2400`），`init(stiffness: CGFloat = 2400)`

- [ ] **Step 1: 写失败测试**

`Tests/ListEffectCoreTests/SpringyEffectTests.swift`:

```swift
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
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter SpringyEffectTests`
Expected: FAIL（`cannot find 'SpringyEffect' in scope`）

- [ ] **Step 3: 写实现**

`Sources/ListEffectCore/SpringyEffect.swift`:

```swift
import CoreGraphics

/// 弹性跟随：离手指越近跟随越"软"（滞后越多），整体随滚动产生波浪/果冻感。
/// 返回的是"本帧应叠加的位移增量"，由 UIKit 驱动器累加并松手回弹。
public struct SpringyEffect: TrackingEffect {
    /// 弹簧硬度。越大跟手越紧（滞后越小），越小越拖沓。
    public var stiffness: CGFloat

    public init(stiffness: CGFloat = 2400) {
        self.stiffness = stiffness
    }

    public func resolve(delta: CGFloat,
                        itemCenter: CGPoint,
                        touch: CGPoint,
                        container: CGSize) -> EffectOutput {
        let resistance = (abs(touch.y - itemCenter.y) + abs(touch.x - itemCenter.x)) / stiffness
        let dy = delta < 0 ? max(delta, delta * resistance) : min(delta, delta * resistance)
        return EffectOutput(translation: CGPoint(x: 0, y: dy))
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `swift test --filter SpringyEffectTests`
Expected: PASS（4 个测试）

- [ ] **Step 5: Commit**

```bash
git add Sources/ListEffectCore/SpringyEffect.swift Tests/ListEffectCoreTests/SpringyEffectTests.swift
git commit -m "feat(core): add SpringyEffect tracking effect"
```

---

### Task 3: ParallaxEffect（PositionEffect）

**Files:**
- Create: `Sources/ListEffectCore/ParallaxEffect.swift`
- Test: `Tests/ListEffectCoreTests/ParallaxEffectTests.swift`（替换 Task 1 的占位测试）

**Interfaces:**
- Consumes: `EffectOutput`、`PositionEffect`（Task 1）
- Produces: `struct ParallaxEffect: PositionEffect`，属性 `amplitude: CGFloat`（默认 `24`），`init(amplitude: CGFloat = 24)`

- [ ] **Step 1: 改写测试为失败测试**

`Tests/ListEffectCoreTests/ParallaxEffectTests.swift`（整文件替换）:

```swift
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
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter ParallaxEffectTests`
Expected: FAIL（`cannot find 'ParallaxEffect' in scope`）

- [ ] **Step 3: 写实现**

`Sources/ListEffectCore/ParallaxEffect.swift`:

```swift
import CoreGraphics

/// 视差位移：cell 随其在视口中的位置上下偏移，产生纵深感。
public struct ParallaxEffect: PositionEffect {
    /// 最大偏移量（pt），在视口上/下边缘处取得。
    public var amplitude: CGFloat

    public init(amplitude: CGFloat = 24) {
        self.amplitude = amplitude
    }

    public func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(translation: CGPoint(x: 0, y: position * amplitude))
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `swift test --filter ParallaxEffectTests`
Expected: PASS（4 个测试）

- [ ] **Step 5: Commit**

```bash
git add Sources/ListEffectCore/ParallaxEffect.swift Tests/ListEffectCoreTests/ParallaxEffectTests.swift
git commit -m "feat(core): add ParallaxEffect position effect"
```

---

### Task 4: RevealEffect（PositionEffect）

**Files:**
- Create: `Sources/ListEffectCore/RevealEffect.swift`
- Test: `Tests/ListEffectCoreTests/RevealEffectTests.swift`

**Interfaces:**
- Consumes: `EffectOutput`、`PositionEffect`（Task 1）
- Produces: `struct RevealEffect: PositionEffect`，属性 `minScale: CGFloat`（默认 `0.8`），`init(minScale: CGFloat = 0.8)`

- [ ] **Step 1: 写失败测试**

`Tests/ListEffectCoreTests/RevealEffectTests.swift`:

```swift
import XCTest
@testable import ListEffectCore

final class RevealEffectTests: XCTestCase {
    func testCenterFullyRevealed() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 0)
        XCTAssertEqual(out.scale, 1, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 1, accuracy: 0.001)
    }

    func testEdgeMinScaleZeroAlpha() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 1)
        XCTAssertEqual(out.scale, 0.8, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0, accuracy: 0.001)
    }

    func testHalfwayInterpolates() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 0.5)
        XCTAssertEqual(out.scale, 0.9, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0.5, accuracy: 0.001)
    }

    func testBeyondEdgeClampsToMin() {
        let out = RevealEffect(minScale: 0.8).resolve(position: 2)
        XCTAssertEqual(out.scale, 0.8, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter RevealEffectTests`
Expected: FAIL（`cannot find 'RevealEffect' in scope`）

- [ ] **Step 3: 写实现**

`Sources/ListEffectCore/RevealEffect.swift`:

```swift
import CoreGraphics

/// 进入视口揭示：cell 越靠近视口中心越完整（scale→1、alpha→1），越靠边/越出界越收缩淡出。
public struct RevealEffect: PositionEffect {
    /// 边缘处的最小缩放。
    public var minScale: CGFloat

    public init(minScale: CGFloat = 0.8) {
        self.minScale = minScale
    }

    public func resolve(position: CGFloat) -> EffectOutput {
        let t = max(0, 1 - min(1, abs(position)))   // 居中=1，到/超过边缘=0
        return EffectOutput(scale: minScale + (1 - minScale) * t, alpha: t)
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `swift test --filter RevealEffectTests`
Expected: PASS（4 个测试）

- [ ] **Step 5: Commit**

```bash
git add Sources/ListEffectCore/RevealEffect.swift Tests/ListEffectCoreTests/RevealEffectTests.swift
git commit -m "feat(core): add RevealEffect position effect"
```

---

### Task 5: UIKit 宿主协议 + Table/Collection 适配

**Files:**
- Create: `Sources/ListEffectUIKit/ListEffectHost.swift`
- Test: `Tests/ListEffectUIKitTests/ListEffectHostTests.swift`

**Interfaces:**
- Produces:
  - `protocol ListEffectHost: AnyObject { var hostScrollView: UIScrollView { get }; func visibleItems() -> [(view: UIView, restingCenter: CGPoint)] }`
  - `UITableView` / `UICollectionView` 均 conform `ListEffectHost`
  - `restingCenter` 为内容坐标系下的中心（与 contentOffset 无关）

- [ ] **Step 1: 扩展 Package.swift，加入 UIKit target/product/test**

本任务是 UIKit target 的第一个源文件，需先在 `Package.swift` 中声明该 target（Task 1 起 Package.swift 仅含 Core）。修改后的 `Package.swift`：

```swift
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
```

- [ ] **Step 2: 写失败测试**

`Tests/ListEffectUIKitTests/ListEffectHostTests.swift`:

```swift
#if canImport(UIKit)
import XCTest
import UIKit
@testable import ListEffectUIKit

private final class FixedDataSource: NSObject, UITableViewDataSource {
    let rows: Int
    init(rows: Int) { self.rows = rows }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { rows }
    func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: nil)
    }
}

final class ListEffectHostTests: XCTestCase {
    func testTableViewVisibleItemsRestingCenter() {
        let tv = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        tv.rowHeight = 44
        let ds = FixedDataSource(rows: 50)
        tv.dataSource = ds
        tv.reloadData()
        tv.layoutIfNeeded()

        let items = tv.visibleItems()
        XCTAssertGreaterThan(items.count, 0)
        // 第一行静止中心 y ≈ rowHeight/2
        let firstCenterY = items.map { $0.restingCenter.y }.min() ?? -1
        XCTAssertEqual(firstCenterY, 22, accuracy: 1.0)
    }
}
#endif
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `swift test --filter ListEffectHostTests`
Expected: FAIL（`value of type 'UITableView' has no member 'visibleItems'`）

- [ ] **Step 4: 写实现**

`Sources/ListEffectUIKit/ListEffectHost.swift`:

```swift
#if canImport(UIKit)
import UIKit

/// 滚动宿主抽象：暴露底层 scrollView 与"可见项 + 静止中心"。
public protocol ListEffectHost: AnyObject {
    var hostScrollView: UIScrollView { get }
    /// 当前可见项：视图本身 + 其在内容坐标系下的静止中心。
    func visibleItems() -> [(view: UIView, restingCenter: CGPoint)]
}

extension UITableView: ListEffectHost {
    public var hostScrollView: UIScrollView { self }

    public func visibleItems() -> [(view: UIView, restingCenter: CGPoint)] {
        (indexPathsForVisibleRows ?? []).compactMap { ip in
            guard let cell = cellForRow(at: ip) else { return nil }
            let r = rectForRow(at: ip)
            return (cell, CGPoint(x: r.midX, y: r.midY))
        }
    }
}

extension UICollectionView: ListEffectHost {
    public var hostScrollView: UIScrollView { self }

    public func visibleItems() -> [(view: UIView, restingCenter: CGPoint)] {
        indexPathsForVisibleItems.compactMap { ip in
            guard let cell = cellForItem(at: ip),
                  let attr = layoutAttributesForItem(at: ip) else { return nil }
            return (cell, attr.center)
        }
    }
}
#endif
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `swift test --filter ListEffectHostTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/ListEffectUIKit/ListEffectHost.swift Tests/ListEffectUIKitTests/ListEffectHostTests.swift
git commit -m "feat(uikit): add ListEffectHost with table/collection conformances"
```

---

### Task 6: UIKit 驱动器（位置效果路径）+ listEffect 命名空间

**Files:**
- Create: `Sources/ListEffectUIKit/ListEffectController.swift`
- Create: `Sources/ListEffectUIKit/UIScrollView+ListEffect.swift`
- Test: `Tests/ListEffectUIKitTests/ListEffectControllerTests.swift`

**Interfaces:**
- Consumes: `ListEffectHost`（Task 5）、`PositionEffect` / `TrackingEffect` / `EffectOutput`（Core）
- Produces:
  - `final class ListEffectController`，方法 `attach(_ effect: PositionEffect)`、`attach(_ effect: TrackingEffect)`、`detach()`
  - `UIScrollView.listEffect: ListEffectController`（associated-object，库自持有）
  - 本任务实现 **position 路径**；tracking 的 `attach(_:)` 先留方法签名但仅记录（Task 7 补全 KVO/累加/归位）

- [ ] **Step 1: 写失败测试**

`Tests/ListEffectUIKitTests/ListEffectControllerTests.swift`:

```swift
#if canImport(UIKit)
import XCTest
import UIKit
import ListEffectCore
@testable import ListEffectUIKit

private final class FixedDataSource: NSObject, UITableViewDataSource {
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { 50 }
    func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: nil)
    }
}

final class ListEffectControllerTests: XCTestCase {
    private var ds: FixedDataSource!

    private func makeTable() -> UITableView {
        let tv = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        tv.rowHeight = 44
        ds = FixedDataSource()
        tv.dataSource = ds
        tv.reloadData()
        tv.layoutIfNeeded()
        return tv
    }

    func testParallaxAppliesTransformOnAttach() {
        let tv = makeTable()
        tv.listEffect.attach(ParallaxEffect(amplitude: 24))

        // 第 0 行：restingCenter.y=22，视口 midY=240，half=240 → position=(22-240)/240
        let position = (22.0 - 240.0) / 240.0
        let expected = CGFloat(position) * 24
        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform.ty, expected, accuracy: 0.5)
    }

    func testDetachResetsTransform() {
        let tv = makeTable()
        tv.listEffect.attach(ParallaxEffect(amplitude: 24))
        tv.listEffect.detach()

        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform, .identity)
        XCTAssertEqual(cell.alpha, 1, accuracy: 0.001)
    }
}
#endif
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter ListEffectControllerTests`
Expected: FAIL（`value of type 'UITableView' has no member 'listEffect'`）

- [ ] **Step 3: 写 ListEffectController（含 position 路径，tracking 占位）**

`Sources/ListEffectUIKit/ListEffectController.swift`:

```swift
#if canImport(UIKit)
import UIKit
import ListEffectCore

/// 滚动动效驱动器。通过 KVO 监听 contentOffset，将效果输出写入可见 cell 的 transform。
/// 不接管宿主的 delegate / dataSource。
public final class ListEffectController {

    enum Attached {
        case position(PositionEffect)
        case tracking(TrackingEffect)
    }

    private weak var host: ListEffectHost?
    var attached: Attached?
    private var offsetObservation: NSKeyValueObservation?

    init(host: ListEffectHost) {
        self.host = host
    }

    public func attach(_ effect: PositionEffect) {
        reset()
        attached = .position(effect)
        startObserving()
        applyPosition()
    }

    public func attach(_ effect: TrackingEffect) {
        reset()
        attached = .tracking(effect)
        // KVO / 累加 / 归位在 Task 7 补全
    }

    public func detach() {
        reset()
    }

    private func startObserving() {
        guard let sv = host?.hostScrollView else { return }
        offsetObservation = sv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.onScroll()
        }
    }

    func onScroll() {
        guard let attached = attached else { return }
        switch attached {
        case .position:
            applyPosition()
        case .tracking:
            break   // Task 7
        }
    }

    private func applyPosition() {
        guard let host = host, case .position(let effect)? = attached else { return }
        let sv = host.hostScrollView
        let midY = sv.contentOffset.y + sv.bounds.height / 2
        let half = sv.bounds.height / 2
        for item in host.visibleItems() {
            let position = half == 0 ? 0 : (item.restingCenter.y - midY) / half
            apply(effect.resolve(position: position), to: item.view)
        }
    }

    func apply(_ out: EffectOutput, to view: UIView) {
        if out.rotation == 0 {
            view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
                .scaledBy(x: out.scale, y: out.scale)
        } else {
            var t = CATransform3DIdentity
            t.m34 = -1.0 / 800
            t = CATransform3DTranslate(t, out.translation.x, out.translation.y, 0)
            t = CATransform3DScale(t, out.scale, out.scale, 1)
            t = CATransform3DRotate(t, out.rotation, 1, 0, 0)
            view.layer.transform = t
        }
        view.alpha = out.alpha
    }

    func reset() {
        offsetObservation = nil
        if let host = host {
            for item in host.visibleItems() {
                item.view.transform = .identity
                item.view.layer.transform = CATransform3DIdentity
                item.view.alpha = 1
            }
        }
        attached = nil
    }
}
#endif
```

- [ ] **Step 4: 写 UIScrollView+ListEffect.swift**

`Sources/ListEffectUIKit/UIScrollView+ListEffect.swift`:

```swift
#if canImport(UIKit)
import UIKit

private var listEffectControllerKey: UInt8 = 0

public extension UIScrollView {
    /// 滚动动效入口。仅对 `UITableView` / `UICollectionView` 有效。
    /// 控制器由 scrollView 通过 associated-object 自持有，使用者无需保存引用。
    var listEffect: ListEffectController {
        if let c = objc_getAssociatedObject(self, &listEffectControllerKey) as? ListEffectController {
            return c
        }
        guard let host = self as? ListEffectHost else {
            fatalError("listEffect 仅支持 UITableView / UICollectionView")
        }
        let c = ListEffectController(host: host)
        objc_setAssociatedObject(self, &listEffectControllerKey, c, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return c
    }
}
#endif
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `swift test --filter ListEffectControllerTests`
Expected: PASS（2 个测试）

- [ ] **Step 6: Commit**

```bash
git add Sources/ListEffectUIKit/ListEffectController.swift Sources/ListEffectUIKit/UIScrollView+ListEffect.swift Tests/ListEffectUIKitTests/ListEffectControllerTests.swift
git commit -m "feat(uikit): add ListEffectController position path and listEffect namespace"
```

---

### Task 7: UIKit 跟随效果路径（累加 + DisplayLink 松手回弹）

**Files:**
- Modify: `Sources/ListEffectUIKit/ListEffectController.swift`
- Test: `Tests/ListEffectUIKitTests/ListEffectControllerTests.swift`（追加测试）

**Interfaces:**
- Consumes: `TrackingEffect`、Task 6 的 `ListEffectController`
- Produces: `attach(_ effect: TrackingEffect)` 完整生效；新增私有累加表与 DisplayLink；KVO 中按 touch+delta 累加并立即应用，DisplayLink 每帧将累加量按 `relaxation` 衰减回零

- [ ] **Step 1: 追加失败测试**

在 `ListEffectControllerTests.swift` 的类中追加：

```swift
    func testTrackingAppliesOffsetOnScroll() {
        let tv = makeTable()
        tv.listEffect.attach(SpringyEffect(stiffness: 2400))

        // 触发一次小幅滚动：delta=10
        tv.contentOffset = CGPoint(x: 0, y: 10)

        // 第 0 行 center≈(160,22)，touch=.zero → resistance=(22+160)/2400≈0.0758
        // dy = min(10, 10*0.0758) ≈ 0.758
        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform.ty, 0.758, accuracy: 0.2)
    }

    func testTrackingDetachResets() {
        let tv = makeTable()
        tv.listEffect.attach(SpringyEffect())
        tv.contentOffset = CGPoint(x: 0, y: 10)
        tv.listEffect.detach()

        let cell = tv.cellForRow(at: IndexPath(row: 0, section: 0))!
        XCTAssertEqual(cell.transform, .identity)
    }
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter ListEffectControllerTests`
Expected: FAIL（`testTrackingAppliesOffsetOnScroll` 断言失败，transform.ty 为 0）

- [ ] **Step 3: 补全 tracking 路径**

在 `ListEffectController` 中新增属性（放在 `offsetObservation` 之后）：

```swift
    private var lastOffsetY: CGFloat = 0
    private var accumulated: [ObjectIdentifier: CGFloat] = [:]
    private var displayLink: CADisplayLink?
    private let relaxation: CGFloat = 0.82
```

将 `attach(_ effect: TrackingEffect)` 改为：

```swift
    public func attach(_ effect: TrackingEffect) {
        reset()
        attached = .tracking(effect)
        lastOffsetY = host?.hostScrollView.contentOffset.y ?? 0
        startObserving()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
```

将 `onScroll()` 的 `.tracking` 分支改为：

```swift
        case .tracking(let effect):
            guard let host = host else { return }
            let sv = host.hostScrollView
            let newY = sv.contentOffset.y
            let delta = newY - lastOffsetY
            lastOffsetY = newY
            let touch = sv.panGestureRecognizer.location(in: sv)
            for item in host.visibleItems() {
                let out = effect.resolve(delta: delta,
                                         itemCenter: item.restingCenter,
                                         touch: touch,
                                         container: sv.bounds.size)
                accumulated[ObjectIdentifier(item.view), default: 0] += out.translation.y
            }
            applyTracking()
```

新增方法：

```swift
    private func applyTracking() {
        guard let host = host else { return }
        for item in host.visibleItems() {
            let y = accumulated[ObjectIdentifier(item.view)] ?? 0
            apply(EffectOutput(translation: CGPoint(x: 0, y: y)), to: item.view)
        }
    }

    @objc private func tick() {
        guard case .tracking? = attached, let host = host else { return }
        var changed = false
        for item in host.visibleItems() {
            let id = ObjectIdentifier(item.view)
            var y = accumulated[id] ?? 0
            guard y != 0 else { continue }
            y *= relaxation
            if abs(y) < 0.5 { y = 0 }
            accumulated[id] = y
            changed = true
        }
        if changed { applyTracking() }
    }
```

在 `reset()` 中追加（`offsetObservation = nil` 之后）：

```swift
        displayLink?.invalidate()
        displayLink = nil
        accumulated.removeAll()
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `swift test --filter ListEffectControllerTests`
Expected: PASS（4 个测试）

- [ ] **Step 5: 全量回归**

Run: `swift test`
Expected: PASS（Core + UIKit 全部）

- [ ] **Step 6: Commit**

```bash
git add Sources/ListEffectUIKit/ListEffectController.swift Tests/ListEffectUIKitTests/ListEffectControllerTests.swift
git commit -m "feat(uikit): add tracking effect path with display-link settle-back"
```

---

### Task 8: SwiftUI ViewModifier（位置效果，iOS 17+）

**Files:**
- Create: `Sources/ListEffectSwiftUI/View+ListEffect.swift`
- Test: `Tests/ListEffectSwiftUITests/ListEffectModifierTests.swift`

**Interfaces:**
- Consumes: `PositionEffect` / `EffectOutput`（Core）
- Produces: `View.listEffect(_ effect: PositionEffect) -> some View`，标注 `@available(iOS 17.0, macOS 14.0, *)`

- [ ] **Step 1: 扩展 Package.swift，加入 SwiftUI target/product/test**

本任务是 SwiftUI target 的第一个源文件，需先在 `Package.swift` 中声明该 target（此前 Package.swift 含 Core + UIKit）。修改后的 `Package.swift`：

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "IListEffect",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "ListEffect-Core", targets: ["ListEffectCore"]),
        .library(name: "ListEffect-UIKit", targets: ["ListEffectUIKit"]),
        .library(name: "ListEffect-SwiftUI", targets: ["ListEffectSwiftUI"]),
    ],
    targets: [
        .target(name: "ListEffectCore"),
        .target(name: "ListEffectUIKit", dependencies: ["ListEffectCore"]),
        .target(name: "ListEffectSwiftUI", dependencies: ["ListEffectCore"]),
        .testTarget(name: "ListEffectCoreTests", dependencies: ["ListEffectCore"]),
        .testTarget(name: "ListEffectUIKitTests", dependencies: ["ListEffectUIKit"]),
        .testTarget(name: "ListEffectSwiftUITests", dependencies: ["ListEffectSwiftUI"]),
    ]
)
```

- [ ] **Step 2: 写 smoke 测试**

`Tests/ListEffectSwiftUITests/ListEffectModifierTests.swift`:

```swift
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
        let wrapped = AnyView(Text("row").listEffect(ParallaxEffect(amplitude: 20)))
        _ = wrapped
    }
}
#endif
```

注：该测试为 smoke 测试，无显式 `XCTAssert`——XCTest 中"运行过程不抛异常即通过"，目的仅是守住"加了 `listEffect` 的视图能编译并构造"这条编译/构建 gate。效果数值逻辑已由 Core 单测覆盖。

- [ ] **Step 3: 运行测试，确认失败**

Run: `swift test --filter ListEffectModifierTests`
Expected: FAIL（`value of type 'Text' has no member 'listEffect'`）

- [ ] **Step 4: 写实现**

`Sources/ListEffectSwiftUI/View+ListEffect.swift`:

```swift
#if canImport(SwiftUI)
import SwiftUI
import ListEffectCore

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    /// 为滚动容器中的行施加位置型效果。基于 `.scrollTransition`，需放在每个 row 上。
    func listEffect(_ effect: PositionEffect) -> some View {
        scrollTransition { content, phase in
            let out = effect.resolve(position: CGFloat(phase.value))
            return content
                .offset(x: out.translation.x, y: out.translation.y)
                .scaleEffect(out.scale)
                .rotation3DEffect(.radians(Double(out.rotation)), axis: (x: 1, y: 0, z: 0))
                .opacity(out.alpha)
        }
    }
}
#endif
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `swift test --filter ListEffectModifierTests`
Expected: PASS（或在 <iOS17 环境下 SKIP）

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/ListEffectSwiftUI/View+ListEffect.swift Tests/ListEffectSwiftUITests/ListEffectModifierTests.swift
git commit -m "feat(swiftui): add listEffect modifier for position effects"
```

---

### Task 9: Demo 工程（XcodeGen，三页：UIKit Table / UIKit Collection / SwiftUI）

**Files:**
- Create: `demo/project.yml`
- Create: `demo/IListEffectDemo/AppDelegate.swift`
- Create: `demo/IListEffectDemo/TableDemoViewController.swift`
- Create: `demo/IListEffectDemo/CollectionDemoViewController.swift`
- Create: `demo/IListEffectDemo/SwiftUIDemoView.swift`

**Interfaces:**
- Consumes: `ListEffect-UIKit`、`ListEffect-SwiftUI`（本地包）

- [ ] **Step 1: 写 project.yml**

`demo/project.yml`:

```yaml
name: IListEffectDemo
options:
  bundleIdPrefix: com.demo
  deploymentTarget:
    iOS: "17.0"
packages:
  IListEffect:
    path: ..
targets:
  IListEffectDemo:
    type: application
    platform: iOS
    sources: [IListEffectDemo]
    dependencies:
      - package: IListEffect
        product: ListEffect-UIKit
      - package: IListEffect
        product: ListEffect-SwiftUI
    settings:
      base:
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 2: 写 AppDelegate（含 TabBar 挂载三页）**

`demo/IListEffectDemo/AppDelegate.swift`:

```swift
import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tab = UITabBarController()
        let table = UINavigationController(rootViewController: TableDemoViewController())
        table.tabBarItem = UITabBarItem(title: "Table", image: UIImage(systemName: "list.bullet"), tag: 0)
        let collection = UINavigationController(rootViewController: CollectionDemoViewController())
        collection.tabBarItem = UITabBarItem(title: "Collection", image: UIImage(systemName: "square.grid.2x2"), tag: 1)
        let swiftui = UIHostingController(rootView: SwiftUIDemoView())
        swiftui.tabBarItem = UITabBarItem(title: "SwiftUI", image: UIImage(systemName: "swift"), tag: 2)
        tab.viewControllers = [table, collection, swiftui]

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = tab
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
```

- [ ] **Step 3: 写 TableDemoViewController（弹性跟随）**

`demo/IListEffectDemo/TableDemoViewController.swift`:

```swift
import UIKit
import ListEffectUIKit
import ListEffectCore

final class TableDemoViewController: UITableViewController {
    private let colors: [UIColor] = [.systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Springy (Tracking)"
        tableView.rowHeight = 64
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        tableView.listEffect.attach(SpringyEffect(stiffness: 2400))
    }

    override func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { 50 }

    override func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        let cell = t.dequeueReusableCell(withIdentifier: "c", for: i)
        cell.backgroundColor = colors[i.row % colors.count].withAlphaComponent(0.85)
        cell.textLabel?.text = "Row #\(i.row)"
        return cell
    }
}
```

- [ ] **Step 4: 写 CollectionDemoViewController（视差，验证同一 API 在 Collection 上）**

`demo/IListEffectDemo/CollectionDemoViewController.swift`:

```swift
import UIKit
import ListEffectUIKit
import ListEffectCore

final class CollectionDemoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Parallax (Position)"
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
        collectionView.listEffect.attach(ParallaxEffect(amplitude: 24))
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { 50 }

    func collectionView(_ cv: UICollectionView, cellForItemAt i: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: i)
        cell.contentView.backgroundColor = colors[i.item % colors.count]
        cell.contentView.layer.cornerRadius = 12
        return cell
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAt i: IndexPath) -> CGSize {
        CGSize(width: cv.bounds.width - 32, height: 80)
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        insetForSectionAt s: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }
}
```

- [ ] **Step 5: 写 SwiftUIDemoView（Reveal，验证双端共用效果）**

`demo/IListEffectDemo/SwiftUIDemoView.swift`:

```swift
import SwiftUI
import ListEffectSwiftUI
import ListEffectCore

struct SwiftUIDemoView: View {
    private let colors: [Color] = [.red, .orange, .green, .blue, .purple]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<50, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors[i % colors.count])
                        .frame(height: 80)
                        .overlay(Text("Row #\(i)").foregroundStyle(.white))
                        .listEffect(RevealEffect(minScale: 0.8))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
```

- [ ] **Step 6: 生成工程并构建验证**

Run:
```bash
cd demo && xcodegen generate && \
xcodebuild -project IListEffectDemo.xcodeproj -scheme IListEffectDemo \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add demo
git commit -m "feat(demo): add table/collection/swiftui demo screens"
```

---

## Self-Review

**Spec coverage（逐条核对 spec → task）：**

- §3 三 target + 命名 + demo → Task 1（包）、Task 9（demo） ✓
- §4 双协议 + EffectOutput → Task 1 ✓
- §5 UIKit host/driver/namespace/归位/诚实约定 → Task 5/6/7 ✓
- §6 SwiftUI ViewModifier + iOS17 gate → Task 8 ✓
- §7 三个效果 + 支持矩阵（Springy=Tracking、Parallax/Reveal=Position） → Task 2/3/4；矩阵由协议归属强制 ✓
- §8 测试策略（Core 表驱动、UIKit 枚举/应用/detach、SwiftUI smoke） → 各 task 的测试步骤 ✓

**Placeholder scan：** 无 TBD/TODO/"类似上面"等；每个代码步骤均含完整代码。✓

**Type consistency：**
- `EffectOutput(translation:scale:rotation:alpha:)` 全程一致；UIKit `apply(_:to:)` 用此初始化器 ✓
- `ListEffectHost.visibleItems() -> [(view: UIView, restingCenter: CGPoint)]` 在 Task 5 定义、Task 6/7 消费，签名一致 ✓
- `attach(_:)` 两个重载（`PositionEffect` / `TrackingEffect`）+ `detach()` 在 Task 6 定义、Task 7 扩展，命名一致 ✓
- `ListEffectController.Attached`、`onScroll()`、`apply(_:to:)`、`reset()` 在 Task 6 引入，Task 7 复用同名 ✓
- 协议名 `PositionEffect` / `TrackingEffect`、效果类型名 `SpringyEffect` / `ParallaxEffect` / `RevealEffect` 全程一致 ✓

无遗留问题。
