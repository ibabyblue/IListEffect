# SlideInEffect 入场效果实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 demo 的 Slide In 入场动画做成 SPM 库的第三条动画路径（`EntranceEffect` 协议 + `SlideInEffect` 实现 + `ListEffectEntrance` 驱动器），支持 UITableView/UICollectionView，demo 改用库能力。

**Architecture:** Core 层新增 `EntranceEffect` 协议（`resolve(progress:) -> EffectOutput` 纯函数）+ `SlideInEffect` 实现；UIKit 层新增 `ListEffectEntrance` 有状态驱动器（CADisplayLink 推进 progress），通过 `UIScrollView.entrance` 扩展暴露，用户在 `willDisplay` 调 `handle(cell:indexPath:)` 桥接。写 `cell.contentView.transform` 避开 layout 重置。

**Tech Stack:** Swift 5.10 / SPM / UIKit（iOS 15+）/ XCTest

## Global Constraints

- 平台：iOS 15+ / macOS 12+（`Package.swift` 已有，不改）
- **禁止未授权 `git commit`/`git push`**：所有提交须用户显式授权。commit message **仅单行 subject**，无 body，无 `Co-Authored-By`
- Core 测试用 `swift test`（macOS）；UIKit 测试**必须**用 iOS 模拟器（`#if canImport(UIKit)` 在 macOS 被排除）：
  ```
  xcodebuild test -scheme IListEffect-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:ListEffectUIKitTests
  ```
- 所有回答/注释用中文
- 复用现有 `EffectOutput`（`Sources/ListEffectCore/EffectOutput.swift`）、`DisplayLinkProxy` 防循环引用套路（`Sources/ListEffectUIKit/ListEffectController.swift`）
- 动画目标始终是 `cell.contentView`（非 `cell`），避开 `UICollectionViewCell.apply(_ layoutAttributes:)` 重置 `cell.transform`

---

## File Structure

新增：
- `Sources/ListEffectCore/EntranceEffect.swift` — 协议（`duration` + `resolve(progress:)`）
- `Sources/ListEffectCore/SlideInEffect.swift` — 实现 + `Timing` 缓动枚举
- `Sources/ListEffectUIKit/ListEffectEntrance.swift` — 驱动器 + `UIScrollView.entrance` 扩展
- `Tests/ListEffectCoreTests/SlideInEffectTests.swift`
- `Tests/ListEffectUIKitTests/ListEffectEntranceTests.swift`

改动：
- `demo/IListEffectDemo/CollectionDemoViewController.swift` — 删除内联纯 UIKit 动画，改用 `SlideInEffect` + `entrance.handle`

---

## Task 1: EntranceEffect 协议（Core）

**Files:**
- Create: `Sources/ListEffectCore/EntranceEffect.swift`
- Create: `Tests/ListEffectCoreTests/EntranceEffectTests.swift`

**Interfaces:**
- Produces: `protocol EntranceEffect { var duration: TimeInterval { get }; func resolve(progress: CGFloat) -> EffectOutput }`

- [ ] **Step 1: 写占位测试验证协议可被实现**

`Tests/ListEffectCoreTests/EntranceEffectTests.swift`:
```swift
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
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter EntranceEffectTests 2>&1 | tail -5`
Expected: FAIL — `cannot find 'EntranceEffect' in scope`

- [ ] **Step 3: 写协议**

`Sources/ListEffectCore/EntranceEffect.swift`:
```swift
import CoreGraphics

/// 入场型效果：cell 首次出现时由 progress(0→1) 驱动的一次性动画。
/// 与 PositionEffect 对称——纯函数，无 UIKit 依赖。
public protocol EntranceEffect {
    /// 单个 cell 动画时长（秒），驱动器据此推进 progress。
    var duration: TimeInterval { get }
    /// progress: 0 = 初始未到位，1 = 归位完成。
    func resolve(progress: CGFloat) -> EffectOutput
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter EntranceEffectTests 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: 提交（需用户授权）**

```bash
git add Sources/ListEffectCore/EntranceEffect.swift Tests/ListEffectCoreTests/EntranceEffectTests.swift
git commit -m "feat(core): add EntranceEffect protocol"
```

---

## Task 2: SlideInEffect + Timing（Core）

**Files:**
- Create: `Sources/ListEffectCore/SlideInEffect.swift`
- Create: `Tests/ListEffectCoreTests/SlideInEffectTests.swift`

**Interfaces:**
- Consumes: `EntranceEffect`（Task 1）、`EffectOutput`
- Produces: `struct SlideInEffect: EntranceEffect`（`amplitude`/`duration`/`timing` + `resolve`）、`SlideInEffect.Timing`

- [ ] **Step 1: 写失败测试**

`Tests/ListEffectCoreTests/SlideInEffectTests.swift`:
```swift
import XCTest
import CoreGraphics
@testable import ListEffectCore

final class SlideInEffectTests: XCTestCase {
    func testProgress0IsInitialOffset() {
        let e = SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut)
        let out = e.resolve(progress: 0)
        XCTAssertEqual(out.translation.x, 220, accuracy: 0.5)
        XCTAssertEqual(out.translation.y, 0, accuracy: 0.001)
        XCTAssertEqual(out.alpha, 0, accuracy: 0.001)
    }

    func testProgress1IsIdentity() {
        let e = SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut)
        let out = e.resolve(progress: 1)
        XCTAssertEqual(out.translation.x, 0, accuracy: 0.5)
        XCTAssertEqual(out.alpha, 1, accuracy: 0.001)
    }

    func testProgressHalfIsMidway() {
        let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: .easeOut)
        let out = e.resolve(progress: 0.5)
        // easeOut: t = 1 - (1-0.5)^3 = 0.875 → x = 100*(1-0.875) = 12.5
        XCTAssertEqual(out.translation.x, 12.5, accuracy: 0.5)
        XCTAssertEqual(out.alpha, 0.875, accuracy: 0.001)
    }

    func testEaseOutBackOvershootsMidway() {
        let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: .easeOutBack)
        let mid = e.resolve(progress: 0.5)
        // easeOutBack 中段 t > 1（回弹），故 alpha > 1、x < 0
        XCTAssertGreaterThan(mid.alpha, 1.0)
        XCTAssertLessThan(mid.translation.x, 0)
    }

    func testTimingEndpoints() {
        for timing in [SlideInEffect.Timing.easeOut, .easeInOut, .easeOutBack] {
            let e = SlideInEffect(amplitude: 100, duration: 0.5, timing: timing)
            XCTAssertEqual(e.resolve(progress: 0).alpha, 0, accuracy: 0.001)
            XCTAssertEqual(e.resolve(progress: 1).alpha, 1, accuracy: 0.001)
        }
    }

    func testDefaults() {
        let e = SlideInEffect()
        XCTAssertEqual(e.amplitude, 220)
        XCTAssertEqual(e.duration, 0.5)
        XCTAssertEqual(e.timing, .easeOutBack)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter SlideInEffectTests 2>&1 | tail -5`
Expected: FAIL — `cannot find 'SlideInEffect' in scope`

- [ ] **Step 3: 写实现**

`Sources/ListEffectCore/SlideInEffect.swift`:
```swift
import CoreGraphics

/// 从右滑入：cell 从右侧偏移位置滑回原位，同时淡入。
public struct SlideInEffect: EntranceEffect {
    public enum Timing {
        case easeOut, easeInOut, easeOutBack

        /// 把线性 progress（0→1）映射为缓动后的 t（可能略超 1，用于回弹）。
        func apply(to progress: CGFloat) -> CGFloat {
            let t = max(0, min(1, progress))
            switch self {
            case .easeOut:
                return 1 - pow(1 - t, 3)
            case .easeInOut:
                return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            case .easeOutBack:
                let c1: CGFloat = 1.70158
                let c3: CGFloat = c1 + 1
                return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
            }
        }
    }

    /// 横向滑入距离（pt），progress=0 时的右偏量。
    public var amplitude: CGFloat
    public var duration: TimeInterval
    public var timing: Timing

    public init(amplitude: CGFloat = 220,
                duration: TimeInterval = 0.5,
                timing: Timing = .easeOutBack) {
        self.amplitude = amplitude
        self.duration = duration
        self.timing = timing
    }

    public func resolve(progress: CGFloat) -> EffectOutput {
        let t = timing.apply(to: progress)
        return EffectOutput(
            translation: CGPoint(x: amplitude * (1 - t), y: 0),
            alpha: t
        )
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter SlideInEffectTests 2>&1 | tail -5`
Expected: PASS（6 tests）

- [ ] **Step 5: 提交（需用户授权）**

```bash
git add Sources/ListEffectCore/SlideInEffect.swift Tests/ListEffectCoreTests/SlideInEffectTests.swift
git commit -m "feat(core): add SlideInEffect entrance effect"
```

---

## Task 3: ListEffectEntrance 驱动器（UIKit）

**Files:**
- Create: `Sources/ListEffectUIKit/ListEffectEntrance.swift`
- Create: `Tests/ListEffectUIKitTests/ListEffectEntranceTests.swift`

**Interfaces:**
- Consumes: `EntranceEffect`（Task 1）、`SlideInEffect`（Task 2）、`EffectOutput`
- Produces: `final class ListEffectEntrance`（`perRowDelay`/`delayRowCap`/`attach`/`detach`/`handle`）、`UIScrollView.entrance` 扩展

**说明：** 驱动器的内部状态（`displayedIndexPaths`/`animating`/`batchIndex`）用 internal（无 `private`），便于 `@testable` 测试直接检查，与 `ListEffectController` 风格一致。

- [ ] **Step 1: 写骨架测试（init/attach/detach + entrance 扩展）**

`Tests/ListEffectUIKitTests/ListEffectEntranceTests.swift`:
```swift
#if canImport(UIKit)
import XCTest
import UIKit
import ListEffectCore
@testable import ListEffectUIKit

final class ListEffectEntranceTests: XCTestCase {
    func testAttachAndDetach() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect())
        entrance.detach()
        // detach 后内部状态清空
        XCTAssertTrue(entrance.displayedIndexPaths.isEmpty)
        XCTAssertTrue(entrance.animating.isEmpty)
    }

    func testEntranceAssociatedObject() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        XCTAssertNotNil(cv.entrance)
        XCTAssertTrue(cv.entrance === cv.entrance, "同一 scrollView 的 entrance 应单例")
    }
}
#endif
```

- [ ] **Step 2: 运行测试确认失败**

Run:
```
xcodebuild test -scheme IListEffect-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ListEffectUIKitTests/ListEffectEntranceTests 2>&1 | grep -E "error:|Executed"
```
Expected: FAIL — `cannot find 'ListEffectEntrance' in scope`

- [ ] **Step 3: 写驱动器骨架（init/attach/detach + entrance 扩展 + handle 占位 + apply）**

`Sources/ListEffectUIKit/ListEffectEntrance.swift`:
```swift
#if canImport(UIKit)
import UIKit
import ListEffectCore

private final class EntranceDisplayLinkProxy: NSObject {
    weak var entrance: ListEffectEntrance?
    init(entrance: ListEffectEntrance) {
        self.entrance = entrance
        super.init()
    }
    @objc func tick() { entrance?.tick() }
}

/// 入场驱动器：在 willDisplay 时调用 handle，对 cell.contentView 做一次性入场动画。
/// 首次出现做动画；回滑再次出现直接归位，不动画。
public final class ListEffectEntrance {
    /// 相邻行错开延迟（秒），首批入场时从上到下依次。
    public var perRowDelay: TimeInterval = 0.05
    /// 同批内错开上限，防止大列表延迟爆炸。
    public var delayRowCap: Int = 12

    var effect: EntranceEffect?
    var displayedIndexPaths = Set<IndexPath>()
    struct AnimState {
        let contentView: UIView
        let start: CFTimeInterval
        let delay: TimeInterval
    }
    var animating: [ObjectIdentifier: AnimState] = [:]
    var lastHandleTime: CFTimeInterval = 0
    var batchIndex: Int = 0
    let batchInterval: CFTimeInterval = 0.05
    private var displayLink: CADisplayLink?
    private var proxy: EntranceDisplayLinkProxy?

    public init() {}

    public func attach(_ effect: EntranceEffect) {
        self.effect = effect
    }

    public func detach() {
        displayLink?.invalidate()
        displayLink = nil
        proxy = nil
        for state in animating.values {
            state.contentView.transform = .identity
            state.contentView.alpha = 1
        }
        animating.removeAll()
        displayedIndexPaths.removeAll()
        batchIndex = 0
    }

    public func handle(cell: UITableViewCell, indexPath: IndexPath) {
        handle(contentView: cell.contentView, indexPath: indexPath)
    }

    public func handle(cell: UICollectionViewCell, indexPath: IndexPath) {
        handle(contentView: cell.contentView, indexPath: indexPath)
    }

    private func handle(contentView: UIView, indexPath: IndexPath) {
        // 占位：Task 后续 step 填充
    }

    func tick() {
        // 占位：Task 后续 step 填充
    }

    private func apply(_ out: EffectOutput, to view: UIView) {
        if out.rotation == 0 {
            view.transform = CGAffineTransform(translationX: out.translation.x, y: out.translation.y)
                .scaledBy(x: out.scale, y: out.scale)
        } else {
            view.transform = .identity
            var t = CATransform3DIdentity
            t.m34 = -1.0 / 800
            t = CATransform3DTranslate(t, out.translation.x, out.translation.y, 0)
            t = CATransform3DScale(t, out.scale, out.scale, 1)
            t = CATransform3DRotate(t, out.rotation, 1, 0, 0)
            view.layer.transform = t
        }
        view.alpha = out.alpha
    }
}

private var entranceKey: UInt8 = 0

public extension UIScrollView {
    /// 入场动效入口。associated object 自持，懒创建；未 attach 时 handle 为 no-op。
    var entrance: ListEffectEntrance {
        if let e = objc_getAssociatedObject(self, &entranceKey) as? ListEffectEntrance {
            return e
        }
        let e = ListEffectEntrance()
        objc_setAssociatedObject(self, &entranceKey, e, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return e
    }
}
#endif
```

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（2 tests）

- [ ] **Step 5: 写首次入场测试**

追加到 `ListEffectEntranceTests` 类：
```swift
    func testHandleAppliesInitialState() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))

        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))

        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        // 初始态：右偏 220 + alpha 0
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5)
        XCTAssertEqual(cell.contentView.alpha, 0, accuracy: 0.001)
        XCTAssertTrue(entrance.displayedIndexPaths.contains(IndexPath(item: 0, section: 0)))
        XCTAssertFalse(entrance.animating.isEmpty)
    }

    func testHandleWithoutAttachIsNoOp() {
        let entrance = ListEffectEntrance()  // 未 attach
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertTrue(entrance.animating.isEmpty)
    }
```

- [ ] **Step 6: 实现 handle + tick + displaylink 启动**

替换 `ListEffectEntrance.swift` 中的占位 `handle` 和 `tick`：

```swift
    private func handle(contentView: UIView, indexPath: IndexPath) {
        guard let effect = effect else { return }
        let id = ObjectIdentifier(contentView)
        if displayedIndexPaths.contains(indexPath) {
            // 回滑：已显示过，移除残留动画，直接归位
            animating.removeValue(forKey: id)
            contentView.transform = .identity
            contentView.alpha = 1
            return
        }
        displayedIndexPaths.insert(indexPath)
        animating.removeValue(forKey: id)  // cell 复用：清除旧条目
        apply(effect.resolve(progress: 0), to: contentView)

        let now = CACurrentMediaTime()
        if now - lastHandleTime < batchInterval {
            batchIndex += 1
        } else {
            batchIndex = 0
        }
        lastHandleTime = now
        let delay = TimeInterval(min(batchIndex, delayRowCap)) * perRowDelay
        animating[id] = AnimState(contentView: contentView, start: now, delay: delay)
        startDisplayLinkIfNeeded()
    }

    func tick() {
        guard let effect = effect, effect.duration > 0 else { return }
        let now = CACurrentMediaTime()
        var done: [ObjectIdentifier] = []
        for (id, state) in animating {
            let elapsed = now - state.start - state.delay
            if elapsed < 0 { continue }
            let progress = min(1, elapsed / effect.duration)
            apply(effect.resolve(progress: progress), to: state.contentView)
            if progress >= 1 { done.append(id) }
        }
        for id in done { animating.removeValue(forKey: id) }
        if animating.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
            proxy = nil
        }
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let p = EntranceDisplayLinkProxy(entrance: self)
        let link = CADisplayLink(target: p, selector: #selector(EntranceDisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        proxy = p
        displayLink = link
    }
```

- [ ] **Step 7: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（4 tests）

- [ ] **Step 8: 写回滑不动画测试**

追加：
```swift
    func testRedisplayDoesNotAnimate() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let ip = IndexPath(item: 0, section: 0)
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: ip)

        entrance.handle(cell: cell, indexPath: ip)   // 首次
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5)

        entrance.handle(cell: cell, indexPath: ip)   // 回滑
        XCTAssertEqual(cell.contentView.transform, .identity)
        XCTAssertEqual(cell.contentView.alpha, 1)
        XCTAssertTrue(entrance.animating.isEmpty, "回滑后应无进行中动画")
    }
```

- [ ] **Step 9: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（5 tests）

- [ ] **Step 10: 写批次延迟测试**

追加：
```swift
    func testBatchDelayStaggered() {
        let entrance = ListEffectEntrance()
        entrance.perRowDelay = 0.05
        entrance.delayRowCap = 12
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")

        // 同批：连续 3 个 handle，间隔 < 50ms
        let c0 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        let c1 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 1, section: 0))
        let c2 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 2, section: 0))
        entrance.handle(cell: c0, indexPath: IndexPath(item: 0, section: 0))
        entrance.handle(cell: c1, indexPath: IndexPath(item: 1, section: 0))
        entrance.handle(cell: c2, indexPath: IndexPath(item: 2, section: 0))

        XCTAssertEqual(entrance.animating[ObjectIdentifier(c1.contentView)]?.delay, 0.05, accuracy: 0.001)
        XCTAssertEqual(entrance.animating[ObjectIdentifier(c2.contentView)]?.delay, 0.10, accuracy: 0.001)
    }

    func testBatchResetAfterInterval() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let c0 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        entrance.handle(cell: c0, indexPath: IndexPath(item: 0, section: 0))

        // 等 > batchInterval(50ms)，新批 batchIndex 归 0
        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let c1 = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 1, section: 0))
        entrance.handle(cell: c1, indexPath: IndexPath(item: 1, section: 0))
        XCTAssertEqual(entrance.animating[ObjectIdentifier(c1.contentView)]?.delay, 0, accuracy: 0.001)
    }
```

- [ ] **Step 11: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（7 tests）

- [ ] **Step 12: 写 cell 复用测试**

追加：
```swift
    func testCellReuseRestartsAnimation() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        let contentView = cell.contentView

        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))
        let firstStart = entrance.animating[ObjectIdentifier(contentView)]?.start

        // 同一 contentView 复用给新 indexPath，应重置动画
        entrance.handle(cell: cell, indexPath: IndexPath(item: 5, section: 0))
        let secondState = entrance.animating[ObjectIdentifier(contentView)]
        XCTAssertNotNil(secondState)
        XCTAssertEqual(cell.contentView.transform.tx, 220, accuracy: 0.5, "复用后回到初始态")
        XCTAssertTrue(entrance.displayedIndexPaths.contains(IndexPath(item: 5, section: 0)))
    }
```

- [ ] **Step 13: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（8 tests）

- [ ] **Step 14: 写动画完成测试（短 duration + 等待）**

追加：
```swift
    func testAnimationCompletesToIdentity() {
        let entrance = ListEffectEntrance()
        entrance.attach(SlideInEffect(amplitude: 220, duration: 0.05, timing: .easeOut))
        let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480),
                                  collectionViewLayout: UICollectionViewFlowLayout())
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
        entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))

        let exp = expectation(description: "animation done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(cell.contentView.transform, .identity, accuracy: 0.5 as? CGAffineTransform)
        XCTAssertEqual(cell.contentView.alpha, 1, accuracy: 0.05)
        XCTAssertTrue(entrance.animating.isEmpty, "完成后应移出 animating")
    }
```

> 说明：`XCTAssertEqual(_, _, accuracy:)` 不支持 `CGAffineTransform`，执行时改用：
> ```swift
> XCTAssertEqual(cell.contentView.transform.tx, 0, accuracy: 0.5)
> XCTAssertEqual(cell.contentView.transform.ty, 0, accuracy: 0.5)
> XCTAssertEqual(cell.contentView.transform.a, 1, accuracy: 0.05)
> XCTAssertEqual(cell.contentView.transform.d, 1, accuracy: 0.05)
> ```
> 实现时按上面四行写入测试文件，忽略 Step 14 代码块里的 `accuracy: 0.5 as? CGAffineTransform` 写法（那仅为示意）。

- [ ] **Step 15: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（9 tests）

- [ ] **Step 16: 写内存测试（displayLink 无强引用循环）**

追加：
```swift
    func testEntranceDeallocatesAfterScrollViewReleased() {
        weak var weakEntrance: ListEffectEntrance?
        autoreleasepool {
            let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
            cv.entrance.attach(SlideInEffect(amplitude: 220, duration: 0.5, timing: .easeOut))
            cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: IndexPath(item: 0, section: 0))
            cv.entrance.handle(cell: cell, indexPath: IndexPath(item: 0, section: 0))  // 启动 displayLink
            weakEntrance = cv.entrance
            XCTAssertNotNil(weakEntrance)
        }
        XCTAssertNil(weakEntrance, "entrance 泄漏 — displayLink 强引用循环？")
    }
```

- [ ] **Step 17: 运行测试确认通过**

Run: 同 Step 2 命令
Expected: PASS（10 tests）

- [ ] **Step 18: 提交（需用户授权）**

```bash
git add Sources/ListEffectUIKit/ListEffectEntrance.swift Tests/ListEffectUIKitTests/ListEffectEntranceTests.swift
git commit -m "feat(uikit): add ListEffectEntrance driver"
```

---

## Task 4: demo 改用库能力

**Files:**
- Modify: `demo/IListEffectDemo/CollectionDemoViewController.swift`（整文件替换）

**Interfaces:**
- Consumes: `SlideInEffect`（Task 2）、`UIScrollView.entrance`（Task 3）

- [ ] **Step 1: 替换 demo 文件**

`demo/IListEffectDemo/CollectionDemoViewController.swift`:
```swift
import UIKit
import ListEffectUIKit
import ListEffectCore

/// Slide In：cell 首次出现时从右侧滑入，回滑不再动画。使用库的 ListEffectEntrance。
final class CollectionDemoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let colors: [UIColor] = [.systemTeal, .systemPink, .systemIndigo, .systemYellow]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Slide In"
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
        view.addSubview(collectionView)
        collectionView.entrance.attach(SlideInEffect())
    }

    func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt i: IndexPath) {
        cv.entrance.handle(cell: cell, indexPath: i)
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

- [ ] **Step 2: 构建 demo 确认编译**

Run:
```
xcodebuild -project demo/IListEffectDemo.xcodeproj -scheme IListEffectDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/iledemo build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 运行 app 手动验证**

Run:
```
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; true
xcrun simctl install booted /tmp/iledemo/Build/Products/Debug-iphonesimulator/IListEffectDemo.app
xcrun simctl launch booted com.demo.IListEffectDemo
```
Expected：app 启动，切到 "Slide In" tab，可见行从上到下依次从右滑入；往下拉新行从右滑入；往上拉回已显示行不再动画。

- [ ] **Step 4: 提交（需用户授权）**

```bash
git add demo/IListEffectDemo/CollectionDemoViewController.swift
git commit -m "refactor(demo): use SlideInEffect from library"
```

---

## Self-Review

**1. Spec 覆盖：**
- 协议 + SlideIn 实现 → Task 1、2 ✓
- ListEffectEntrance 驱动器 + entrance 扩展 → Task 3 ✓
- 首次入场动画 → Task 3 Step 5-7 ✓
- 回滑不动画 → Task 3 Step 8-9 ✓
- 批次延迟（首批错开/滚动不延迟）→ Task 3 Step 10-11 ✓
- cell 复用 → Task 3 Step 12-13 ✓
- 动画完成 → Task 3 Step 14-15 ✓
- detach → Task 3 Step 1（testAttachAndDetach）✓
- 内存（displayLink 循环）→ Task 3 Step 16-17 ✓
- demo 改用库 → Task 4 ✓
- contentView 而非 cell → Task 3 apply 写 `view.transform`，handle 传 `cell.contentView` ✓
- Core 纯函数可单测 → Task 2 ✓

**2. 占位符扫描：** 无 TBD/TODO。Task 3 Step 14 有个 `accuracy: 0.5 as? CGAffineTransform` 的示意写法已在说明里修正为四行断言，执行时按说明写入。

**3. 类型一致性：** `EntranceEffect.duration`/`resolve(progress:)`、`SlideInEffect(amplitude:duration:timing:)`、`ListEffectEntrance(perRowDelay/delayRowCap/attach/detach/handle)`、`UIScrollView.entrance`、`handle(cell:indexPath:)` 两个重载——全 plan 一致。`AnimState`（contentView/start/delay）、`tick()`、`apply(_:to:)` 签名一致。

**4. 缺口：** spec 提到"CI 改动不在本期范围，仅记录 iOS 测试指令"——已在 Global Constraints 记录指令，无需 task。
