# IListEffect

为可滚动列表（UIKit `UITableView` / `UICollectionView` 与 SwiftUI）提供**与滚动关联的动画效果**的 Swift Package。

内置三套招牌效果：
- 「弹性跟手」`SpringyCollectionLayout`：UIDynamics 真实弹簧，带惯性回弹（Collection 专属，手感最佳）
- 「从右滑入」`SlideInEffect`：cell 首次出现时从右侧滑入到原位（Table / Collection 通用）
- 「缩放揭示」`RevealEffect`：cell 进入视口时缩放 + 淡入（SwiftUI）

## 特性

- 🎯 **双端**：UIKit 与 SwiftUI 各有适配层，核心效果数学完全共用
- 🧩 **可扩展**：新增效果只需实现协议，适配层零改动
- 🪶 **接入轻量**：不接管宿主的 `delegate` / `dataSource`

## 环境要求

- Swift 5.10+
- iOS 15+ / macOS 12+
- SwiftUI 的滚动效果需 iOS 17+ / macOS 14+（基于 `.scrollTransition`）

## 安装（Swift Package Manager）

`Package.swift`：

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/IListEffect.git", from: "0.1.0")
]
```

或在 Xcode：**File → Add Package Dependencies…** 输入仓库地址。

三个产品按需依赖：

| Product | 模块 | 用途 |
|---------|------|------|
| `ListEffect-Core` | `ListEffectCore` | 纯效果逻辑（零 UI 依赖） |
| `ListEffect-UIKit` | `ListEffectUIKit` | UIKit 适配（依赖 Core） |
| `ListEffect-SwiftUI` | `ListEffectSwiftUI` | SwiftUI 适配（依赖 Core） |

## 用法

### UIKit · 弹性跟手（UIDynamics 真弹簧）

`SpringyCollectionLayout` 仅适用于 `UICollectionView`，手感最佳：

```swift
import ListEffectUIKit

let layout = SpringyCollectionLayout()
layout.springFrequency = 2.2        // 硬度：越大越紧
layout.springDamping = 0.92         // 阻尼：越大越少晃
layout.scrollResistanceFactor = 3000 // 波浪幅度：越大滞后越小
let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
```

### UIKit · 入场滑入（Table + Collection）

cell 首次出现时从右侧滑入；回滑再次出现不动画。通过 `entrance` 入口挂载，在 `cellForItemAt` 预置初始态、`willDisplay` 触发动画：

```swift
import ListEffectUIKit
import ListEffectCore

// viewDidLoad
tableView.entrance.attach(SlideInEffect())

func tableView(_ tv: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
    let cell = tv.dequeueReusableCell(...)
    tv.entrance.prepare(cell: cell)          // cell 创建/复用即预置初始态，防快速滚动跳变
    return cell
}

func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt i: IndexPath) {
    tv.entrance.handle(cell: cell, indexPath: i)   // 滚动进入的新 cell 立即滑入（delay=0）
}

// 首批：viewDidAppear 批量触发，按行从上到下依次错开
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    for cell in tableView.visibleCells.sorted(by: { ... }) {
        guard let i = tableView.indexPath(for: cell) else { continue }
        let delay = TimeInterval(min(i.row, tableView.entrance.delayRowCap)) * tableView.entrance.perRowDelay
        tableView.entrance.handle(cell: cell, indexPath: i, delay: delay)
    }
}
```

> ⚠️ 入场动画会接管 cell 的 `contentView.transform` / `alpha`，请勿同时对同一 cell 施加自定义 transform。

### SwiftUI（iOS 17+）

逐 row 加修饰符，仅接受位置型效果：

```swift
import SwiftUI
import ListEffectSwiftUI
import ListEffectCore

ScrollView {
    LazyVStack {
        ForEach(items) { item in
            RowView(item)
                .listEffect(RevealEffect(minScale: 0.8))
        }
    }
}
```

## 内置效果与支持矩阵

| 效果 | 路径 | UIKit | SwiftUI | 说明 |
|------|------|:---:|:---:|------|
| `SpringyCollectionLayout` | Layout | ✅ Collection | — | UIDynamics 真弹簧，带惯性回弹 |
| `SlideInEffect` | Entrance | ✅ Table / Collection | — | 首次出现从右滑入；回滑不动画 |
| `RevealEffect` | Position | — | ✅ | 进入视口时缩放 + 淡入 |

`SlideInEffect` 实现 `EntranceEffect` 协议（UIKit 入场驱动 `ListEffectEntrance`）；`RevealEffect` 实现 `PositionEffect` 协议（SwiftUI `.listEffect` 基于 `.scrollTransition`，位置驱动）。

## 扩展自定义效果

实现对应协议即可，适配层无需改动：

```swift
import ListEffectCore

// SwiftUI 位置型：实现 PositionEffect，配合 .listEffect 使用
struct FadeEdgesEffect: PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(alpha: 1 - min(1, abs(position)))
    }
}

// UIKit 入场型：实现 EntranceEffect，配合 ListEffectEntrance 使用
struct FadeInEffect: EntranceEffect {
    var duration: TimeInterval { 0.4 }
    func resolve(progress: CGFloat) -> EffectOutput {
        EffectOutput(alpha: progress)
    }
}
```

`PositionEffect` 的 `position` 为归一化视口位置（-1 顶部外 … 0 居中 … 1 底部外）；`EntranceEffect` 的 `progress` 为入场进度（0 初始 … 1 归位）。

## 架构

```
ListEffectCore     纯效果逻辑（EffectOutput / PositionEffect / EntranceEffect / 内置效果），零 UI 依赖
ListEffectUIKit    SpringyCollectionLayout（UIDynamics）+ ListEffectEntrance（入场驱动，UIView.animate）
ListEffectSwiftUI  基于 .scrollTransition 的 ViewModifier（iOS 17+）
```

效果的「数学」与「宿主控件」解耦：`SlideInEffect` / `RevealEffect` 等是纯函数（`resolve`），由各自平台的驱动器调用。

## 许可

MIT
