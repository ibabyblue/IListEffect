# SlideInEffect 入场效果设计

> 日期：2026-06-22
> 状态：待实现
> 范围：ListEffectCore + ListEffectUIKit（UIKit 双容器，不含 SwiftUI）

## 1. 背景与目标

demo 的 Parallax tab 已改为"从右滑入"入场动画，当前实现是写在 `CollectionDemoViewController` 里的纯 UIKit 代码，未使用 SPM 库。原因：库现有的 `PositionEffect` 是基于视口位置的纯函数（`resolve(position:)`），cell 经过中心会继续变化，做不到"滑到原位停住"的一次性入场。

本设计把"首次出现入场"做成 SPM 库的第三条动画路径，使 demo 的 Slide In tab 改用库能力，并为后续入场效果（Fade/Zoom 等）留扩展点。

### 需求

- cell **首次出现**时从右侧滑入到原位（一次性入场，非持续）。
- **往回滑动**时已显示过的 cell 再次进入视口，不再做动画，直接归位。
- 支持 `UITableView` 与 `UICollectionView`。
- 首次加载时可见行从上到下依次错开入场；滚动进入的新行立即入场，不延迟。

## 2. 架构定位

库现有两条动画路径，入场路径为第三条，独立组件，不与前两条耦合：

| 路径 | 驱动 | 触发时机 | 状态 | 现有组件 |
|---|---|---|---|---|
| 效果路径 | KVO contentOffset | 滚动中持续 | 无状态函数 | `ListEffectController` |
| layout 路径 | UIDynamics | 滚动中持续 | 弹簧物理 | `SpringyCollectionLayout` |
| **入场路径** | **CADisplayLink** | **cell 首次显示（willDisplay）** | **有状态** | **`ListEffectEntrance`（新增）** |

入场路径不与 `ListEffectController` 共享代码——后者是 KVO contentOffset 驱动，拿不到 willDisplay 事件，强行合并破坏单一职责。但复用公共输出类型 `EffectOutput`，以及"写 `cell.contentView.transform` 避开 layout 重置"这一已验证结论。

## 3. Core 层 API

`EntranceEffect` 协议与 `PositionEffect` 对称——`resolve(...) -> EffectOutput` 纯函数，无 UIKit 依赖：

```swift
// ListEffectCore/EntranceEffect.swift
public protocol EntranceEffect {
    /// 单个 cell 动画时长（秒），驱动器据此推进 progress。
    var duration: TimeInterval { get }
    /// progress: 0 = 初始未到位，1 = 归位完成
    func resolve(progress: CGFloat) -> EffectOutput
}
```

`SlideInEffect` 首个实现：

```swift
// ListEffectCore/SlideInEffect.swift
public struct SlideInEffect: EntranceEffect {
    public enum Timing { case easeOut, easeInOut, easeOutBack }

    public var amplitude: CGFloat          // 横向滑入距离（pt），progress=0 时的右偏量
    public var duration: TimeInterval      // 单个 cell 动画时长（秒）
    public var timing: Timing              // 缓动曲线

    public init(amplitude: CGFloat = 220,
                duration: TimeInterval = 0.5,
                timing: Timing = .easeOutBack)

    public func resolve(progress: CGFloat) -> EffectOutput {
        let t = timing.apply(to: progress)
        return EffectOutput(
            translation: CGPoint(x: amplitude * (1 - t), y: 0),
            alpha: t
        )
    }
}
```

`Timing.apply(to:)` 是 `SlideInEffect` 内部的纯数学缓动（easeOutBack 提供轻微回弹，复现 demo 的 spring 感），不放公共协议——缓动是效果自己的实现细节。

### 设计要点

- `progress` 由 UIKit 层驱动（displaylink 每帧推进），Core 只负责"给定进度算输出"，可单测、无 UIKit。
- 默认值对齐当前 demo 观感（amplitude 220、duration 0.5）。
- **编排参数与效果解耦**：`perRowDelay`/`delayRowCap` 是"入场节奏"，归驱动器 `ListEffectEntrance`（见第 4 节），不放进协议——不同入场效果共享同一编排，且未来某效果不需要延迟时不受协议强制。`duration` 提到协议，因驱动器推进 progress 需要它。

## 4. UIKit 层 API

`ListEffectEntrance` 是有状态驱动器，通过 `UIScrollView.entrance` 扩展暴露（associated object 自持，风格对齐 `listEffect`）：

```swift
// ListEffectUIKit/ListEffectEntrance.swift
public final class ListEffectEntrance {
    public var perRowDelay: TimeInterval = 0.05   // 相邻行错开延迟（秒）
    public var delayRowCap: Int = 12              // 同批内错开上限
    public func attach(_ effect: EntranceEffect)
    public func detach()
}

public extension UIScrollView {
    var entrance: ListEffectEntrance { get }   // associated object，懒创建
}
```

### 挂载与触发（用户视角）

```swift
// viewDidLoad
collectionView.entrance.attach(SlideInEffect())

// willDisplay 桥接（UITableView / UICollectionView 各一个重载）
func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell,
                    forItemAt i: IndexPath) {
    cv.entrance.handle(cell: cell, indexPath: i)
}
```

`entrance` 首次访问时懒创建一个无效果的 `ListEffectEntrance`；未 `attach` 时 `handle` 为 no-op，避免未配置即触发崩溃。

`handle` 两个重载，内部统一取 `cell.contentView` 做动画：

```swift
func handle(cell: UITableViewCell, indexPath: IndexPath)
func handle(cell: UICollectionViewCell, indexPath: IndexPath)
```

## 5. 延迟规则：首批错开，滚动不延迟

用**批次时间窗口**区分首批与滚动，而非全局 row：

- `handle` 记录时间戳。距上一次 `handle` < `batchInterval`（默认 50ms）→ 同批，`batchIndex += 1`；否则新批，`batchIndex = 0`。
- `delay = min(batchIndex, delayRowCap) * perRowDelay`

| 场景 | batchIndex | delay |
|---|---|---|
| 首批加载（十几个 cell 几十 ms 内连续 willDisplay） | 0→递增 | 从上到下依次错开 |
| 滚动新行（单个 cell，距上次 >50ms） | 0 | 0，立即入场 |
| 回滑已显示行 | — | 不进动画表，直接归位 |

`delayRowCap` 限制同批内错开上限（一批最多十几个可见 cell，cap=12 足够），不因全局 row 增大而延迟爆炸。

## 6. 数据流

```
cell 首次显示
  │
  ▼
用户 willDisplay → cv.entrance.handle(cell, indexPath)
  │
  ▼
handle():
  1. if indexPath in displayedIndexPaths:
        cell.contentView 直接设为 final（identity, alpha=1)   ← 回滑，不动画
        return
  2. displayedIndexPaths.insert(indexPath)
  3. 设 cell.contentView 为 effect.resolve(progress:0)         ← 初始态
  4. 算 batchIndex（时间窗口）→ delay = min(batchIndex, cap) * perRowDelay
  5. animating[ObjectIdentifier(cell.contentView)] = AnimState(start, delay, ...)
  6. 若 displayLink 未启动 → 启动
  │
  ▼
CADisplayLink tick()（每帧）:
  for each (id, state) in animating:
    elapsed = now - state.start - state.delay
    if elapsed < 0: continue                                  ← 延迟等待期
    progress = clamp(elapsed / duration, 0, 1)
    out = effect.resolve(progress: progress)
    apply(out, to: 对应 contentView)                           ← 写 contentView.transform / alpha
    if progress >= 1:
        移出 animating[id]
  if animating.isEmpty: 暂停 displayLink
```

`apply` 复用 `ListEffectController.apply` 的同款逻辑（仿射通道写 `view.transform`，alpha 单独写），目标始终是 `contentView`。

### 边界处理

- **cell 在动画中被复用**：`handle` 入口检测 `ObjectIdentifier(contentView)` 是否已在 `animating` 中，命中则先移除旧条目再建新的——新 indexPath 重新走首次入场逻辑。
- **detach**：清空 `animating`/`displayedIndexPaths`，还原所有可见 contentView 为 identity，`displayLink.invalidate()`。
- **displayLink 生命周期**：复用 `ListEffectController` 已验证的 `DisplayLinkProxy`（weak controller）防强引用循环；无动画时暂停而非销毁，下次 `handle` 唤醒。
- **进度曲线**：`progress` 是线性 elapsed/duration，缓动由 `SlideInEffect.resolve` 内部 `Timing.apply` 完成——Core 负责非线性，UIKit 只提供线性进度。

## 7. 关键决策

1. **contentView 而非 cell**：入场路径写 `cell.contentView.transform`，复用效果路径已验证结论——`UICollectionViewCell.apply(_ layoutAttributes:)` 会重置 `cell.transform` 但不动 `contentView`。`UITableView`/`UICollectionView` 行为一致，不重蹈 Parallax 在 collection 上失效的覆辙。
2. **不接管 delegate**：用户保留 delegate，只在 `willDisplay` 加一行 `handle`。符合库现有原则，无 swizzle/代理风险。
3. **首批 vs 滚动**：批次时间窗口统一处理，一个 delay 公式覆盖两种场景，无需 `didInitialAnimation` flag。
4. **Core 纯函数 / UIKit 有状态**：`EntranceEffect.resolve(progress:)` 无 UIKit 依赖、可单测；`ListEffectEntrance` 独占状态与 displaylink。
5. **第三条独立路径**：不塞进 `ListEffectController`，驱动模型不同。
6. **YAGNI**：本期只做 `SlideInEffect` + 三种缓动。不预设 Fade/Zoom/FromLeft（协议已留扩展点）。SwiftUI 暂不支持。

## 8. 测试策略

| 层 | 测试 | 说明 |
|---|---|---|
| Core | `SlideInEffect.resolve` 端点 | progress=0 → translation.x=amplitude, alpha=0；progress=1 → identity, alpha=1；progress=0.5 → 中间值 |
| Core | `Timing` 缓动 | 端点（0→0, 1→1）+ easeOutBack 中段超 1（回弹特性） |
| UIKit | `handle` 首次入场 | willDisplay 后 contentView 处于初始态；tick 推进后归 identity |
| UIKit | 回滑不动画 | 同 indexPath 二次 handle → 立即 identity，不进 animating 表 |
| UIKit | 批次延迟 | 短时间连续 handle → delay 递增；间隔 >50ms → delay 归 0 |
| UIKit | cell 复用 | 动画中复用同 contentView → 旧条目清除、新 indexPath 重新入场 |
| UIKit | detach | 清空状态、可见 contentView 还原、displayLink 停 |
| UIKit | 内存 | entrance 随 scrollView 释放后 deinit（displayLink 无强引用循环） |

### 测试基础设施缺口

现有 UIKit 测试用 `swift test`（macOS）跑不了（`#if canImport(UIKit)` 被排除），只能 `xcodebuild` iOS 模拟器跑——这是 Parallax bug 漏测的根因之一。本期 UIKit 测试必须用 iOS 模拟器跑：

```
xcodebuild test -scheme IListEffect-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ListEffectUIKitTests
```

CI 改动不在本期实现范围，仅在 README 记录该指令。

## 9. 文件清单

新增：
- `Sources/ListEffectCore/EntranceEffect.swift` — 协议
- `Sources/ListEffectCore/SlideInEffect.swift` — 实现 + Timing
- `Sources/ListEffectUIKit/ListEffectEntrance.swift` — 驱动器 + UIScrollView.entrance 扩展
- `Tests/ListEffectCoreTests/SlideInEffectTests.swift`
- `Tests/ListEffectUIKitTests/ListEffectEntranceTests.swift`

改动：
- `demo/IListEffectDemo/CollectionDemoViewController.swift` — 改用 `SlideInEffect` + `entrance.handle`，删除内联纯 UIKit 动画

## 10. 不做

- SwiftUI 入场效果（`.transition`/`onAppear` 另有原生手段，后续单独加）。
- FadeIn/ZoomIn/FromLeft 等其他入场效果（协议已留扩展点，需要时再加）。
- CI 配置改动（仅记录 iOS 测试指令）。
