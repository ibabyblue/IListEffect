# IListEffect 设计文档

- 日期：2026-06-20
- 状态：待评审
- 类型：SPM 库设计（滚动列表动效）

## 1. 目标与背景

提供一个可复用的 SPM 库，为可滚动列表（`UITableView` / `UICollectionView` / SwiftUI `List`·`ScrollView`）施加与滚动关联的动画效果，**首个招牌效果是"弹性跟随"（UIDynamics 风格的果冻感）**。

设计的两条硬约束：

1. **双端**：同时支持 UIKit 与 SwiftUI。
2. **可扩展**：后续新增其它滚动动效时，不改动适配层架构，只新增效果实现。

### 非目标（YAGNI）

- 不做 Android（但核心传递函数公式刻意保持平台无关，便于他端照抄）。
- v1 不做"改变 cell 真实布局占位/插入删除联动"的效果（那类需 CollectionView 专属 Layout 路径，留待后续）。
- 不在 iOS 15~16 上为 SwiftUI 补 GeometryReader 兜底（见 §4）。

## 2. 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 地基控件 | **`UIScrollView` + 对可见 cell 施加 transform** | `UITableView` 无可注入的 layout 对象；`UIScrollView` 是两者唯一共同父类，一套代码覆盖 Table/Collection/裸 ScrollView |
| 是否用 UIDynamics | **否** | `UIDynamicAnimator` 绑死 `UICollectionViewLayout`，无法覆盖 UITableView，且难单测、调参靠玄学 |
| 核心抽象 | **双协议**（`PositionEffect` / `TrackingEffect`） | UIKit 是 push（delta+touch），SwiftUI 是 pull（视口 phase），输入模型本质不同；强行统一会泄漏抽象 |
| SwiftUI 版本下限 | **位置效果 iOS 17+**（`@available` gate），包平台仍 iOS 15 | `.scrollTransition` 为 iOS 17+；GeometryReader 兜底脆弱、双轨维护，否掉 |

## 3. 架构与 target 划分

沿用 ISkeleton 的三层骨架与命名习惯（包名带 `I` 前缀、target 去前缀、product 用连字符）：

```
Package: IListEffect   (iOS 15 / macOS 12, swift-tools 5.10)
├── ListEffectCore      纯 Swift，零 UI 依赖 —— 效果传递函数
├── ListEffectUIKit     依赖 Core —— UIScrollView 适配（覆盖 UITableView + UICollectionView）
└── ListEffectSwiftUI   依赖 Core —— ViewModifier 适配（位置效果, iOS 17+ gate）

products:  ListEffect-Core / ListEffect-UIKit / ListEffect-SwiftUI
tests:     ListEffectCoreTests / ListEffectUIKitTests / ListEffectSwiftUITests
demo:      demo/（XcodeGen project.yml，沿用 ISkeleton/demo 模式，含 Table+Collection+SwiftUI 三个页面）
```

**职责边界**

- `ListEffectCore`：不 import UIKit/SwiftUI，只做"输入滚动状态 → 输出视觉变换"的纯数学。可单测、可跨端、可跨平台抄公式。
- `ListEffectUIKit`、`ListEffectSwiftUI`：互不依赖，各自实现一端适配，均依赖 Core。

## 4. 核心抽象（ListEffectCore）

扩展性的命门。按"能力(capability)"拆成两个协议，**让"跨端能力差异"成为类型系统里的事实，而非文档口头约定**。

```swift
/// 两端共用的输出
public struct EffectOutput: Equatable {
    public var translation: CGPoint = .zero
    public var scale: CGFloat = 1
    public var rotation: CGFloat = 0      // 弧度，用于 3D/2D 旋转
    public var alpha: CGFloat = 1
    public init() {}
}

/// 位置型效果：输入归一化位置（-1 顶部外 … 0 居中 … 1 底部外），双端均可实现
public protocol PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput
}

/// 跟随型效果：依赖触摸位置与每帧位移，UIKit 专属
public protocol TrackingEffect {
    func resolve(delta: CGFloat,
                 itemCenter: CGPoint,
                 touch: CGPoint,
                 container: CGSize) -> EffectOutput
}
```

- UIKit driver 同时消费两种协议；SwiftUI ViewModifier **只**消费 `PositionEffect`。
- 一个效果通过"实现哪个协议"自然声明其支持的端。新增效果 = 新增一个 struct 实现对应协议，**适配层一行不改**。
- 被否方案：单一 `ScrollEffect` 统一协议。需塞一个大 input 结构体，SwiftUI 侧拿不到 touch/delta 只能传 0，调用方无法分辨哪些字段有效——泄漏抽象。

## 5. UIKit 适配（ListEffectUIKit）

### 入口（associated-object，库自持有，使用者无需存 property）

```swift
tableView.listEffect.attach(SpringyEffect())        // UITableView
collectionView.listEffect.attach(ParallaxEffect())  // UICollectionView，写法一致
tableView.listEffect.detach()                        // 复位所有可见 cell 的 transform
```

### 宿主抽象

```swift
public protocol ListEffectHost: AnyObject {
    var hostScrollView: UIScrollView { get }
    /// 可见项：视图 + 其"静止中心"（用于算偏移基准与归一化位置）
    func visibleItems() -> [(view: UIView, restingCenter: CGPoint)]
}
```

- `UITableView`：`indexPathsForVisibleRows` + `cellForRow` + `rectForRow(at:).mid`。
- `UICollectionView`：`indexPathsForVisibleItems` + `cellForItem` + `layoutAttributesForItem(at:).center`。

### 驱动器

- KVO 监听 `contentOffset`（**不接管 delegate**），每次回调：
  - `TrackingEffect`：用 `panGestureRecognizer.location` 与本帧 delta 调 `resolve(...)`。
  - `PositionEffect`：由 cell 静止中心相对视口换算归一化 `position` 调 `resolve(position:)`。
  - 输出写入 `cell.transform`（平移/缩放/alpha）；含 3D 旋转时走 `cell.layer.transform`（带 `m34` 透视）。
- **自动归位**：`TrackingEffect` 在 `scrollViewDidEndDragging` / 减速结束时，把残留 transform 以动画收回 identity（替代 UIDynamics 的"松手回弹"）。`PositionEffect` 连续自校正，无需归位。

### 诚实约定

- 库接管 `cell.transform`（与 `layer.transform`）。文档明示：使用者若自行使用 cell.transform 会冲突。
- `detach()` 复位所有可见 cell。

## 6. SwiftUI 适配（ListEffectSwiftUI）

### 入口（row 级 ViewModifier，只接受 `PositionEffect`）

```swift
// iOS 17+
ForEach(items) { item in
    RowView(item).listEffect(ParallaxEffect())
}
```

- 类型系统层面就拒绝 `TrackingEffect`（`SpringyEffect` 无法传入），与支持矩阵一致。
- 内部用 `.scrollTransition { view, phase in ... }` 把 `phase.value`（-1…0…1）喂给 `PositionEffect.resolve(position:)`，输出映射到 `.offset / .scaleEffect / .rotation3DEffect / .opacity`。
- 整组 SwiftUI 效果 API 用 `@available(iOS 17, *)` gate；低版本调用编译期提示不可用。

## 7. v1 效果清单与支持矩阵

| 效果 | 协议 | UIKit | SwiftUI | 说明 |
|------|------|:---:|:---:|------|
| `SpringyEffect` | `TrackingEffect` | ✅ | ❌ | 招牌弹性跟随（果冻感）；参数：`stiffness` 等语义化调参 |
| `ParallaxEffect` | `PositionEffect` | ✅ | ✅ | 视差位移 |
| `RevealEffect` | `PositionEffect` | ✅ | ✅ | 进入视口时缩放 + 淡入 |

矩阵中的 ❌ 由类型系统强制（`SpringyEffect` 不实现 `PositionEffect`，无法进入 SwiftUI 入口），非文档承诺。

一个跟随型验证 UIKit 专属路径；两个位置型验证"双端共用同一传递函数 + 扩展性"。

## 8. 测试策略

- **Core（重点）**：对每个 effect 的 `resolve(...)` 做表驱动纯函数单测（输入位置/位移 → 断言 `EffectOutput`）。核心逻辑零 UI 依赖，可确定性验证——这是双协议拆分的最大红利。
- **UIKit**：测 `visibleItems()` 枚举正确、driver 把输出正确写到 `transform`、`detach()` 复位生效。
- **SwiftUI**：iOS 17 gate 下 smoke test（modifier 能编译组合、不崩）；真实视觉效果靠 demo 目测。

## 9. 公开 API 汇总

- Core：`EffectOutput`、`PositionEffect`、`TrackingEffect`、`SpringyEffect`、`ParallaxEffect`、`RevealEffect`
- UIKit：`UIScrollView.listEffect`（命名空间）、`attach(_:)`、`detach()`、`ListEffectHost`
- SwiftUI：`View.listEffect(_:)`（`@available(iOS 17, *)`）

## 10. 未决/后续

- 后续效果（3D 翻入、吸顶渐变等）按所属协议追加，复用现有适配层。
- 需要"改变真实布局占位"的效果时，再评估增设 CollectionView 专属 Layout 路径作为可选高级适配。
- 库的发布与 CI（如 swift test + 多设备 matrix）单独规划。
