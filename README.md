# IListEffect

A Swift Package providing **scroll-linked animation effects** for scrollable lists (UIKit `UITableView` / `UICollectionView` and SwiftUI).

Three headline effects ship out of the box:
- **Springy follow** — `SpringyCollectionLayout`: real UIDynamics springs with inertial bounce (Collection-only, best feel).
- **Slide-in** — `SlideInEffect`: cells slide in from the right on first appearance (Table / Collection).
- **Reveal** — `RevealEffect`: cells scale + fade in as they enter the viewport (SwiftUI).

## Features

- 🎯 **Cross-platform**: separate adapters for UIKit and SwiftUI, sharing the same core effect math.
- 🧩 **Extensible**: add an effect by conforming to a protocol — no adapter changes required.
- 🪶 **Lightweight integration**: never takes over the host's `delegate` / `dataSource`.

## Requirements

- Swift 5.10+
- iOS 15+ / macOS 12+
- SwiftUI scroll effects require iOS 17+ / macOS 14+ (built on `.scrollTransition`).

## Installation (Swift Package Manager)

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/IListEffect.git", from: "0.2.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter the repository URL.

Depend on whichever products you need:

| Product | Module | Purpose |
|---------|------|------|
| `ListEffect-Core` | `ListEffectCore` | Pure effect logic (no UI dependencies) |
| `ListEffect-UIKit` | `ListEffectUIKit` | UIKit adapter (depends on Core) |
| `ListEffect-SwiftUI` | `ListEffectSwiftUI` | SwiftUI adapter (depends on Core) |

## Usage

### UIKit · Springy follow (real UIDynamics springs)

`SpringyCollectionLayout` is `UICollectionView`-only and offers the best feel:

```swift
import ListEffectUIKit

let layout = SpringyCollectionLayout()
layout.springFrequency = 2.2         // stiffness: higher = tighter
layout.springDamping = 0.92          // damping: higher = less wobble
layout.scrollResistanceFactor = 3000 // wave amplitude: higher = less lag
let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
```

### UIKit · Slide-in entrance (Table + Collection)

Cells slide in from the right on first appearance; scrolling back over already-shown cells does not re-animate. Mount via the `entrance` entry, preset the initial state in `cellForItemAt`, and trigger the animation in `willDisplay`:

```swift
import ListEffectUIKit
import ListEffectCore

// viewDidLoad
tableView.entrance.attach(SlideInEffect())

func tableView(_ tv: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
    let cell = tv.dequeueReusableCell(...)
    tv.entrance.prepare(cell: cell)          // preset initial state on create/reuse; avoids flicker on fast scroll
    return cell
}

func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt i: IndexPath) {
    tv.entrance.handle(cell: cell, indexPath: i)   // newly scrolled-in cells slide in immediately (delay=0)
}

// Initial batch: trigger in viewDidAppear, staggered top-to-bottom by row
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    for cell in tableView.visibleCells.sorted(by: { ... }) {
        guard let i = tableView.indexPath(for: cell) else { continue }
        let delay = TimeInterval(min(i.row, tableView.entrance.delayRowCap)) * tableView.entrance.perRowDelay
        tableView.entrance.handle(cell: cell, indexPath: i, delay: delay)
    }
}
```

> ⚠️ The entrance animation takes over the cell's `contentView.transform` / `alpha`. Do not apply a custom transform to the same cell concurrently.

### SwiftUI (iOS 17+)

Apply the modifier per row; it only accepts position-based effects:

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

## Built-in effects and support matrix

| Effect | Path | UIKit | SwiftUI | Notes |
|------|------|:---:|:---:|------|
| `SpringyCollectionLayout` | Layout | ✅ Collection | — | Real UIDynamics springs with inertial bounce |
| `SlideInEffect` | Entrance | ✅ Table / Collection | — | Slides in from the right on first appearance; no re-animate on scroll-back |
| `RevealEffect` | Position | — | ✅ | Scale + fade in as cells enter the viewport |

`SlideInEffect` conforms to the `EntranceEffect` protocol (driven by the UIKit `ListEffectEntrance` driver); `RevealEffect` conforms to the `PositionEffect` protocol (SwiftUI's `.listEffect` is built on `.scrollTransition`, which is position-driven).

## Custom effects

Conform to the relevant protocol — no adapter changes needed:

```swift
import ListEffectCore

// SwiftUI position-based: conform to PositionEffect and use with .listEffect
struct FadeEdgesEffect: PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(alpha: 1 - min(1, abs(position)))
    }
}

// UIKit entrance: conform to EntranceEffect and use with ListEffectEntrance
struct FadeInEffect: EntranceEffect {
    var duration: TimeInterval { 0.4 }
    func resolve(progress: CGFloat) -> EffectOutput {
        EffectOutput(alpha: progress)
    }
}
```

For `PositionEffect`, `position` is the normalized in-viewport position (-1 top outside … 0 centered … 1 bottom outside). For `EntranceEffect`, `progress` is the entrance progress (0 initial … 1 settled).

## Architecture

```
ListEffectCore     Pure effect logic (EffectOutput / PositionEffect / EntranceEffect / built-in effects), no UI dependencies
ListEffectUIKit    SpringyCollectionLayout (UIDynamics) + ListEffectEntrance (entrance driver, UIView.animate)
ListEffectSwiftUI  ViewModifier built on .scrollTransition (iOS 17+)
```

Effect **math** is decoupled from the **host control**: `SlideInEffect` / `RevealEffect` are pure functions (`resolve`) invoked by each platform's driver.

## License

MIT
