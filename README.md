# IListEffect

A Swift Package providing **scroll-linked animation effects** for scrollable lists (UIKit `UITableView` / `UICollectionView` and SwiftUI).

Three headline effects ship out of the box:
- **Springy follow** — `SpringyCollectionLayout`: real UIDynamics springs with inertial bounce (Collection-only, best feel).
- **Slide-in** — `SlideInEffect`: cells slide in from the right on first appearance (UIKit & SwiftUI).
- **Reveal** — `RevealEffect`: cells scale + fade in as they enter the viewport (UIKit & SwiftUI).

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

Cells slide in from the right on first appearance; scrolling back over already-shown cells does not re-animate. The `entrance` driver samples `effect.resolve(progress:)` per frame via `CADisplayLink`, so the effect's timing curve (e.g. `SlideInEffect`'s ease-out-back) is now honored. Three core calls cover the whole flow:

```swift
import ListEffectUIKit
import ListEffectCore

// viewDidLoad — mount the effect
tableView.entrance.attach(SlideInEffect())

// viewDidAppear — stagger the first visible batch top-to-bottom by row (idempotent, runs once)
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    tableView.entrance.animateInitialBatch()
}

// willDisplay — newly scrolled-in cells slide in immediately (delay = 0)
func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt i: IndexPath) {
    tv.entrance.handle(cell: cell, indexPath: i)
}
```

Optional optimization — `prepare(cell:)` pre-sets the initial state on dequeue to eliminate edge flicker during very fast scrolling. It is now optional: `handle` also seeds the initial state, so skipping `prepare` no longer flickers:

```swift
func tableView(_ tv: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
    let cell = tv.dequeueReusableCell(...)
    tv.entrance.prepare(cell: cell)   // optional
    return cell
}
```

> ⚠️ The entrance animation takes over the cell's `contentView.transform` / `alpha`. Do not apply a custom transform to the same cell concurrently.

### UIKit · Position-based effects (Reveal, custom)

For scroll-linked position effects on UIKit (the same family SwiftUI's `.listEffect` exposes), use the `scrollEffect` entry — it KVO-observes `contentOffset` and never takes over the host's `delegate`:

```swift
// viewDidLoad
tableView.scrollEffect.attach(RevealEffect(minScale: 0.8))
```

Detach with `tableView.scrollEffect.detach()`.

### SwiftUI (iOS 17+)

Two modifiers, mirroring the UIKit entries:

- `.listEffect(_:)` — position-based, scroll-linked (built on `.scrollTransition`, apply per row). Honors `rotationAxis` / `anchor`.
- `.entranceEffect(_:)` — one-shot entrance on first appear (e.g. `SlideInEffect`). Note: in a `LazyVStack`, scroll-back destroys and rebuilds rows, so the entrance replays — a SwiftUI paradigm that differs from UIKit's "show once" behavior.

```swift
import SwiftUI
import ListEffectSwiftUI
import ListEffectCore

ScrollView {
    LazyVStack {
        ForEach(items) { item in
            RowView(item)
                .listEffect(RevealEffect(minScale: 0.8))   // position-based
                // or one-shot entrance:
                // .entranceEffect(SlideInEffect())
        }
    }
}
```

## Built-in effects and support matrix

| Effect | UIKit | SwiftUI | Notes |
|------|:---:|:---:|------|
| `SpringyCollectionLayout` | ✅ Collection | — | Real UIDynamics springs with inertial bounce |
| `SlideInEffect` | ✅ Table / Collection | ✅ | Entrance; slides in from the right on first appearance. UIKit: no re-animate on scroll-back. |
| `RevealEffect` | ✅ Table / Collection | ✅ | Position; scale + fade in as cells enter the viewport |

Entry points:

| Entry | Platform | Family | Drives |
|------|------|------|------|
| `scrollView.entrance` | UIKit | `EntranceEffect` | `ListEffectEntrance` (CADisplayLink per-frame sampling; timing now in effect) |
| `scrollView.scrollEffect` | UIKit | `PositionEffect` | `PositionEffectDriver` (KVO on `contentOffset`) |
| `.entranceEffect(_:)` | SwiftUI | `EntranceEffect` | one-shot on appear |
| `.listEffect(_:)` | SwiftUI | `PositionEffect` | `.scrollTransition` |

`SlideInEffect` conforms to `EntranceEffect`; `RevealEffect` conforms to `PositionEffect`. Both effect families share the same `EffectOutput` fields.

### EffectOutput fields

| Field | Type | Default | Meaning |
|------|------|------|------|
| `translation` | `CGPoint` | `.zero` | x/y offset |
| `scale` | `CGFloat` | `1` | uniform scale |
| `rotation` | `CGFloat` | `0` | rotation in **radians** |
| `alpha` | `CGFloat` | `1` | opacity |
| `rotationAxis` | `RotationAxis?` | `nil` (→ `.z`) | rotation axis; `.z` = 2D in-plane, `.x` = 3D tilt |
| `perspective` | `CGFloat?` | `nil` (→ `-1/800`, the `m34` component) | 3D perspective; only affects rotations with a component parallel to the screen (`.x`). **UIKit-only** — consumed only by the UIKit drivers (`entrance` / `scrollEffect` via `CATransform3D` m34); SwiftUI's `.listEffect` / `.entranceEffect` use a fixed perspective (`1`) and ignore this field. |
| `anchor` | `AnchorPoint?` | `nil` (→ `.center`) | rotation/scale anchor in normalized `0…1` space |

## Custom effects

Conform to the relevant protocol — no adapter changes needed:

```swift
import ListEffectCore

// Position-based (SwiftUI .listEffect / UIKit scrollView.scrollEffect):
struct FadeEdgesEffect: PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(alpha: 1 - min(1, abs(position)))
    }
}

// Entrance (UIKit scrollView.entrance / SwiftUI .entranceEffect):
struct FadeInEffect: EntranceEffect {
    var duration: TimeInterval { 0.4 }
    func resolve(progress: CGFloat) -> EffectOutput {
        EffectOutput(alpha: progress)
    }
}

// 3D tilt using the new EffectOutput fields (rotationAxis / perspective / anchor).
// Note: `perspective` is honored only on UIKit (scrollView.scrollEffect / entrance);
// SwiftUI's .listEffect / .entranceEffect apply a fixed perspective and ignore it.
struct TiltEffect: PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(rotation: position * 0.4,
                     rotationAxis: .x,
                     perspective: -0.002)
    }
}
```

For `PositionEffect`, `position` is the normalized in-viewport position (-1 top outside … 0 centered … 1 bottom outside). For `EntranceEffect`, `progress` is the entrance progress (0 initial … 1 settled).

## Architecture

```
ListEffectCore     Pure effect logic (EffectOutput / PositionEffect / EntranceEffect / built-in effects), no UI dependencies
ListEffectUIKit    SpringyCollectionLayout (UIDynamics) + ListEffectEntrance (CADisplayLink entrance driver) + PositionEffectDriver (KVO position driver)
ListEffectSwiftUI  ViewModifiers built on .scrollTransition / onAppear (iOS 17+)
```

Effect **math** is decoupled from the **host control**: `SlideInEffect` / `RevealEffect` are pure functions (`resolve`) invoked by each platform's driver.

## License

MIT
