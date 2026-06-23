# IListEffect 易用性与扩展性提升设计

日期：2026-06-23
状态：待实现

## 1. 背景与目标

IListEffect 是一个面向 `UITableView` / `UICollectionView` / SwiftUI 的滚动联动动效 SPM 库（当前 0.2.0）。代码评审发现两类问题：

- **易用性**：UIKit 入场效果（`ListEffectEntrance`）号称「轻量接入」，实际需要 4 个调用点 + ~20 行样板（首批 stagger 编排、`didInitialAnimate` 状态、`prepare` 防闪烁），且「首批 vs 滚动」的区分逻辑全部外泄给调用方。
- **扩展性**：`EffectOutput` 固定 4 维（translation/scale/rotation/alpha），渲染细节（旋转轴、透视）写死，天花板明显；且存在一个实质缺陷——入场驱动器只采样 `resolve(0)` / `resolve(1)` 端点，`SlideInEffect.Timing`（easeOutBack）从未生效。

**目标**：降低接入成本、修复 timing 失效、突破 `EffectOutput` 能力天花板、补齐 UIKit / SwiftUI 两端能力对称。

## 2. 范围与约束

- **范围**：评审提出的 5 条建议全部纳入，按依赖关系分三阶段实现。
- **API 兼容**：允许破坏性变更（0.x 语义化版本）。Demo 同步改写。
- **平台**：iOS 15+ / macOS 12+；SwiftUI 滚动相关 API 仍要求 iOS 17+ / macOS 14+。
- **核心原则不变**：不接管宿主的 `delegate` / `dataSource`。
- **阶段顺序**：A（UIKit 入场，1+2+4）→ B（EffectOutput 扩展，3）→ C（两端对称，5）。B 先于 C，因 C 的新适配器消费扩展后的 `EffectOutput`。

## 3. 阶段 A — UIKit 入场效果

### A1. 首批 stagger 编排收口

`ListEffectEntrance` 新增：

```swift
public func animateInitialBatch()
```

行为：
- 遍历宿主 `visibleCells`，按 `indexPath` 升序排序；
- 对每个 cell 计算 `delay = TimeInterval(min(row, delayRowCap)) * perRowDelay`；
- 调用内部动画入口（与 `handle` 共享），从上到下错开入场；
- **幂等**：entrance 自持 `initialBatchTriggered: Bool`（替代调用方的 `didInitialAnimate`），仅首次执行。

时序约定：
- 首批 cell 的 `willDisplay` 先于 `viewDidAppear` 触发；此时 `initialBatchTriggered == false`，`handle` 内部 no-op，等待 `animateInitialBatch`；
- `viewDidAppear` 调 `animateInitialBatch`：置 `initialBatchTriggered = true` 并对可见 cell 做 stagger；
- 此后滚动进入的新 cell 触发 `handle`，按 `delay = 0` 立即入场。

调用方从「4 处 + 20 行样板」收敛为三处一行：

```swift
viewDidLoad:   tableView.entrance.attach(SlideInEffect())
viewDidAppear: tableView.entrance.animateInitialBatch()
willDisplay:   tableView.entrance.handle(cell: cell, indexPath: indexPath)
```

### A2. prepare 内化（降级为可选）

- `handle` 在启动动画前自带兜底：先 `applyEffectOutput(effect.resolve(progress: 0), to: contentView)` 设置初始态。**即使调用方漏调 `prepare`，也不再出现从原位跳到初始态的闪烁。**
- `prepare(cell:)` 保留为 public，定位为「可选优化」（cell 创建/复用瞬间预置初始态，进一步消除快速滚动边缘场景），文档与命名明确「可选」。
- 净效果：核心路径 3 处一行调用，`prepare` 非必需。

### A3. 驱动曲线下放 + 修复 timing 失效

**缺陷根因**：现状 `handle` 只取 `resolve(0)` 与 `resolve(1)` 两端点，由 `UIView.animate(withDuration:usingSpringWithDamping:0.85 ...)` 在两值间插值；`SlideInEffect.resolve(progress)` 内部的 `timing.apply(to: progress)` 仅对中间 progress 有效，端点恒为 0/1，故 easeOutBack 从未生效。

**方案：`CADisplayLink` 逐帧驱动**
- entrance 持有一个懒创建的 `CADisplayLink`（加入 `.common` runloop），有活跃动画时启动、无时暂停。
- 活跃动画登记表：`animations: [ObjectIdentifier: Animation]`，其中 `Animation { contentView; start: CFTimeInterval; indexPath }`；`duration` 取自 `effect.duration`。
- 每帧回调：对每条记录
  - `progress = clamp01((displayLink.targetTimestamp - start) / duration)`；
  - `applyEffectOutput(effect.resolve(progress: progress), to: contentView)` —— `resolve` 内部 `timing.apply` 在逐帧中生效；
  - `progress >= 1`：移除该记录；无活跃记录时暂停 displayLink。
- 启动时：`applyEffectOutput(resolve(0))` 设初始态，登记 `start = displayLink.targetTimestamp`。
- 生命周期：cell 复用（`handle` 重入 / `prepare`）清除该 contentView 的旧记录；`detach()` 停止 displayLink 并清空记录与 `displayedIndexPaths`。

**曲线下放到 effect**
- spring 不再写死在驱动器。
- `SlideInEffect.Timing` 新增 `.spring(damping:frequency:)` case，其 `apply(to:)` 用解析弹簧函数（基于阻尼/频率的闭合解）把线性 progress 映射为带回弹的 t；效果对象按需选择。
- `EntranceEffect` 协议语义补全：`duration` 驱动总时长，`resolve(progress:)` 内部决定曲线（含 timing）。

**约束**：入场动画仍占用 `contentView.transform` / `layer.transform` / `alpha`（3D 通道在 `rotationAxis` 生效时使用，见阶段 B），与调用方自身 transform/alpha 互斥，沿用现有警告。

## 4. 阶段 B — EffectOutput 扩展

采用「加可选字段」方案（保持 Core 零 UI 依赖、类型安全、可测）。

`EffectOutput` 新增可选字段：

| 字段 | 类型 | 默认（nil 时） | 说明 |
|------|------|----------------|------|
| `rotationAxis` | `RotationAxis?` | `(0, 0, 1)` 绕 Z 轴 | **行为变更**：现实现写死绕 X 轴 `(1,0,0)`，且 `rotation` 注释「2D/3D 旋转」自相矛盾。默认改为绕 Z（真正的 2D 平面旋转，符合 `rotation` 直觉）；需 3D 倾斜显式设 `(1,0,0)`。无内置效果使用 rotation，不受影响。 |
| `perspective` | `CGFloat?` | `-1.0 / 800` | 3D 透视强度（m34）。 |
| `anchor` | `AnchorPoint?` | `AnchorPoint(x: 0.5, y: 0.5)`（中心） | 旋转/缩放锚点（归一化 0…1，平台无关）。 |

`RotationAxis` 定义于 Core：

```swift
public struct RotationAxis: Equatable {
    public var x, y, z: CGFloat
    public init(x: CGFloat, y: CGFloat, z: CGFloat)
    public static let z = RotationAxis(x: 0, y: 0, z: 1)   // 2D 平面旋转（默认）
    public static let x = RotationAxis(x: 1, y: 0, z: 0)   // 3D 倾斜
}
```

- 注意：`RotationAxis` 不依赖 UIKit/SwiftUI（纯 `CGFloat`），Core 可定义。
- `anchor` 用 `UnitPoint` 需要 SwiftUI；为避免 Core 引入 SwiftUI 依赖，Core 内用平台无关的归一化表示 `AnchorPoint(x: CGFloat, y: CGFloat)`（0…1），两端 adapter 各自映射到 `UnitPoint` / `CALayer` anchor。
- 两端 apply 逻辑读取这些可选值：`applyEffectOutput`（UIKit）与 `.listEffect` / `.entranceEffect`（SwiftUI）按字段调整旋转轴、透视、锚点；nil 走默认。

## 5. 阶段 C — 两端对称

### C1. UIKit position 驱动器（让 `RevealEffect` 在 UIKit 可用）

不接管 delegate → **KVO `scrollView.contentOffset`**。

- `UIScrollView` 新增关联对象入口：

  ```swift
  var scrollEffect: PositionEffectDriver { get }
  ```

- `PositionEffectDriver`：
  - `attach(_ effect: PositionEffect)` / `detach()`：保存 effect；attach 时 KVO 注册 `contentOffset`（`.new`），detach 停止；生命周期随 scrollView（关联对象持有）。
  - KVO 回调：遍历 `scrollView.visibleCells`（tableView/collectionView 转型），对每个 cell 算归一化位置 `position = (cellCenter.y - viewportCenterY) / (viewportHeight / 2)`（居中 0、到/超边缘 ±1+），调 `effect.resolve(position:)`，`applyEffectOutput` 到 `contentView`。
  - 性能：仅算可见 cell；scroll 帧回调内避免分配。
- 与入场效果冲突提示：position 与 entrance 都写 `contentView.transform/alpha`，同一 cell 不应同时启用两种，文档注明。

### C2. SwiftUI 入场适配器（让 `SlideInEffect` 在 SwiftUI 可用）

新增：

```swift
@available(iOS 17.0, macOS 14.0, *)
public extension View {
    func entranceEffect(_ effect: EntranceEffect) -> some View
}
```

- 实现：自定义 `ViewModifier`，`animatableData` 暴露 `progress: CGFloat`；`body` 内 `effect.resolve(progress: progress)` 应用 offset/scale/rotation/opacity（读取阶段 B 扩展字段）。
- 触发：`.onAppear { withAnimation(.linear(duration: effect.duration)) { progress = 1 } }`；`withAnimation` 插值 `animatableData`，逐帧重算 `body`，`resolve(progress)` 内部 `timing.apply` 生效（与 UIKit DisplayLink 路径一致）。
- **已知限制**：`LazyVStack` 回滑销毁重建后 `onAppear` 再触发，入场会重播（SwiftUI 范式，与 UIKit「回滑不再动画」不一致）。文档明确说明。

## 6. 测试策略

- **Core（纯函数）**
  - `EffectOutput` 新字段默认值与赋值；
  - `SlideInEffect.resolve` 中间 progress 值（验证 easeOutBack 形状，如 progress=0.5 时 t>0.5）；
  - 新 `.spring` Timing 的端点（0→0、1→1）与单调/回弹特性；
  - `RotationAxis` 预设。
- **UIKit**
  - `animateInitialBatch` 幂等（二次调用不重复动画）；
  - DisplayLink 启停：detach 后无残留、progress 到 1 自动清除；
  - `handle` 兜底初始态（漏 prepare 不闪烁，以快照/状态断言）；
  - `scrollEffect` KVO：attach 后 offset 变化触发 resolve，detach 后停止。
- **SwiftUI**
  - `entranceEffect` onAppear 后 progress 0→1 推进（用 `TimelineView`/预览断言或属性测试）；
  - `.listEffect` 读取 `rotationAxis`/`perspective`/`anchor`（扩展字段接线）。

## 7. Demo 改动

- `CollectionDemoViewController`：改写为 A 阶段新 3 行 API（attach / animateInitialBatch / handle），移除手写 stagger 样板与 `didInitialAnimate`。
- 新增 demo：
  - UIKit · `RevealEffect`（通过 `scrollEffect` + KVO）——展示 C1；
  - SwiftUI · `SlideInEffect`（通过 `.entranceEffect`）——展示 C2；
  - 视情况增加自定义效果（旋转轴/透视）demo——展示 B。
- README 同步更新用法、能力矩阵（两端对称后 SlideIn/Reveal 在 UIKit/SwiftUI 均可用）、自定义效果示例。

## 8. 风险与缓解

| 风险 | 缓解 |
|------|------|
| DisplayLink 生命周期复杂，存在泄漏/残留风险 | 统一登记表 + `detach` 清空 + 单测验证启停；displaylink 与 entrance（关联对象）同生命周期 |
| timing 改 DisplayLink 后手感变化（原 spring 行为不再默认） | 提供 `.spring` Timing 复刻原手感；默认 `SlideInEffect` 选用接近原手感的 timing |
| C1 KVO 大列表性能 | 仅 visibleCells、回调内零分配；必要时节流 |
| C2 回滑重播与 UIKit 不一致 | 文档明确为已知限制，非缺陷 |
| `rotationAxis` 默认绕 Z 属行为变更 | 无内置效果受影响；README 标注；破坏性变更已授权 |

## 9. 验收标准

- 阶段 A：Demo 入场接入为 3 行核心调用；`SlideInEffect` 的 easeOutBack 在运行中可见；`animateInitialBatch` 二次调用幂等。
- 阶段 B：`EffectOutput` 新字段两端可渲染；自定义效果能设置非默认旋转轴/透视/锚点并生效；Core 单测通过。
- 阶段 C：`RevealEffect` 在 UIKit、`SlideInEffect` 在 SwiftUI 均可用且动画正确；`scrollEffect` detach 后停止 KVO。
- 全部：`swift test` 通过；Demo 可运行；README 与能力矩阵更新。
