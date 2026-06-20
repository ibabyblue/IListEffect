# IListEffect

为可滚动列表（UIKit `UITableView` / `UICollectionView` 与 SwiftUI）提供**与滚动关联的动画效果**的 Swift Package。

首发招牌效果是「弹性跟手」（UIDynamics 真实弹簧，带惯性回弹），并通过双协议设计为后续扩展更多滚动动效留好口子。

## 特性

- 🎯 **双端**：UIKit 与 SwiftUI 各有适配层，核心效果数学完全共用
- 🧩 **可扩展**：新增效果只需实现协议，适配层零改动
- 🔒 **类型安全的能力边界**：能否在 SwiftUI 使用由协议归属在编译期强制
- 🪶 **接入轻量**：UIKit 一行接入，不接管宿主的 `delegate` / `dataSource`
- 🌊 **两套弹性**：UIDynamics 真弹簧（Collection 专属）+ transform 通用近似（Table+Collection）

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

### UIKit · 弹性跟手（推荐，UIDynamics 真弹簧）

`SpringyCollectionLayout` 仅适用于 `UICollectionView`，手感最佳：

```swift
import ListEffectUIKit

let layout = SpringyCollectionLayout()
layout.springFrequency = 2.2        // 硬度：越大越紧
layout.springDamping = 0.92         // 阻尼：越大越少晃
layout.scrollResistanceFactor = 3000 // 波浪幅度：越大滞后越小
let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
```

### UIKit · 通用效果（Table + Collection）

在 `UITableView` / `UICollectionView` 上一行接入，库自持有，不抢 delegate：

```swift
import ListEffectUIKit
import ListEffectCore

tableView.listEffect.attach(ParallaxEffect(amplitude: 24))      // UITableView
collectionView.listEffect.attach(SpringyEffect(stiffness: 2400)) // UICollectionView，写法一致
// 移除并复位
tableView.listEffect.detach()
```

> ⚠️ 本库会接管可见 cell 的 `transform` / `layer.transform` / `alpha`，请勿同时对同一 cell 施加自定义 transform。

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

| 效果 | 协议 | UIKit | SwiftUI | 说明 |
|------|------|:---:|:---:|------|
| `SpringyCollectionLayout` | （Layout） | ✅ Collection | — | UIDynamics 真弹簧，手感最佳 |
| `SpringyEffect` | `TrackingEffect` | ✅ | ❌ | transform 通用弹性近似（带位移上限防重叠） |
| `ParallaxEffect` | `PositionEffect` | ✅ | ✅ | 视差位移 |
| `RevealEffect` | `PositionEffect` | ✅ | ✅ | 进入视口时缩放 + 淡入 |

矩阵中的 ❌ 由类型系统强制：`TrackingEffect` 依赖触摸与每帧位移，SwiftUI 的 `.scrollTransition` 是位置驱动、拿不到这些量，故 `listEffect(_:)` 只接受 `PositionEffect`。

## 扩展自定义效果

实现对应协议即可，适配层无需改动：

```swift
import ListEffectCore

// 位置型（双端可用）
struct FadeEdgesEffect: PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(alpha: 1 - min(1, abs(position)))
    }
}
```

`PositionEffect` 的 `position` 为归一化位置（-1 顶部外 … 0 居中 … 1 底部外）。

## 架构

```
ListEffectCore     纯效果传递函数（EffectOutput / PositionEffect / TrackingEffect / 内置效果），零 UI 依赖
ListEffectUIKit    UIScrollView + KVO + cell transform 驱动（覆盖 Table/Collection）；UIDynamics SpringyCollectionLayout
ListEffectSwiftUI  基于 .scrollTransition 的 ViewModifier（iOS 17+）
```

效果的「数学」与「宿主控件」解耦：同一套 `PositionEffect` 传递函数被 UIKit 与 SwiftUI 两端复用。

## 许可

MIT
