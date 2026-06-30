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
- iOS 15+ / macOS 12+ for Core. `ListEffect-UIKit` is an iOS/UIKit product.
- SwiftUI scroll effects require iOS 17+ / macOS 14+ (built on `.scrollTransition`).

## Installation (Swift Package Manager)

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/IListEffect.git", from: "0.3.1")
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter the repository URL.

Depend on whichever products you need:

| Product | Module | Purpose |
|---------|------|------|
| `ListEffect-Core` | `ListEffectCore` | Pure effect logic (no UI dependencies) |
| `ListEffect-UIKit` | `ListEffectUIKit` | iOS/UIKit adapter (depends on Core) |
| `ListEffect-SwiftUI` | `ListEffectSwiftUI` | SwiftUI adapter (depends on Core; scroll APIs require iOS 17+ / macOS 14+) |

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

For mutable lists, prefer a stable business identity so inserts, deletes, and reordering do not make a new row inherit an old row's "already shown" state:

```swift
func tableView(_ tv: UITableView, willDisplay cell: UITableViewCell, forRowAt i: IndexPath) {
    let item = items[i.row]
    tv.entrance.handle(cell: cell, id: item.id, indexPath: i)
}

// When replacing the whole data source and intentionally replaying entrance:
tableView.entrance.resetEnteredState()
```

Optional optimization — `prepare(cell:)` pre-sets the initial state on dequeue to eliminate edge flicker during very fast scrolling. It is now optional: `handle` also seeds the initial state, so skipping `prepare` no longer flickers:

```swift
func tableView(_ tv: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
    let cell = tv.dequeueReusableCell(...)
    tv.entrance.prepare(cell: cell)   // optional
    return cell
}
```

> ⚠️ The UIKit adapters apply transforms and alpha to the cell itself, not `contentView`. Do not apply another transform/alpha animation to the same cell concurrently.

### UIKit · Position-based effects (Reveal, custom)

For scroll-linked position effects on UIKit (the same family SwiftUI's `.listEffect` exposes), use the `scrollEffect` entry — it KVO-observes `contentOffset` and never takes over the host's `delegate`:

```swift
// viewDidLoad
tableView.scrollEffect.attach(RevealEffect(minScale: 0.8))
```

Detach with `tableView.scrollEffect.detach()`.

If visible cells change without a scroll event (for example after `reloadData()`, rotation, or stationary insert/delete), call `tableView.scrollEffect.applyNow()` after layout to refresh the current visible cells.

### SwiftUI (iOS 17+)

Two row modifiers, mirroring the UIKit entries, plus one container modifier for entrance:

- `.listEffect(_:)` — position-based, scroll-linked (built on `.scrollTransition`, apply per row). Honors `rotationAxis` / `anchor`.
- `.entranceEffect(_:id:)` — one-shot entrance keyed by a stable business identity; recommended for mutable lists.
- `.entranceEffect(_:index:)` — compatibility overload keyed by index; use only for static lists.
- `.listEntrance()` — **container** modifier on the `ScrollView`. Installs a shared coordinator + real-visibility tracking so each row enters exactly once and never replays on scroll-back.

> **Note:** SwiftUI entrance is currently **experimental**. The demo has it disabled (uses scroll-linked Reveal instead) while we refine the experience. The APIs remain available; feel free to enable and tune (`perRowDelay`/`delayRowCap`) for your use case.

Why the container: a bare `.onAppear` entrance in a `LazyVStack` fires in the off-screen render buffer, so the animation often finishes before the row is actually visible — some rows appear pre-settled, others animate, and the list looks fragmented. `.listEntrance()` drives the entrance from real scroll geometry instead of `onAppear` timing, so every row that scrolls in slides in consistently (no fragmentation), the first screen still staggers top-to-bottom, and rows scrolled back into view do **not** replay — matching UIKit's "show once" semantics.

```swift
import SwiftUI
import ListEffectSwiftUI
import ListEffectCore

ScrollView {
    LazyVStack {
        ForEach(items) { item in
            RowView(item)
                // Entrance (experimental):
                // .entranceEffect(SlideInEffect(), id: item.id)
                // Position-based (stable):
                .listEffect(RevealEffect(minScale: 0.8))
        }
    }
}
// .listEntrance()   // required for entrance to work reliably
```

## Built-in effects and support matrix

| Effect | UIKit | SwiftUI | Notes |
|------|:---:|:---:|------|
| `SpringyCollectionLayout` | ✅ Collection | — | Real UIDynamics springs with inertial bounce |
| `SlideInEffect` | ✅ Table / Collection | ✅ | Entrance; slides in from the right on first appearance, no re-animate on scroll-back (SwiftUI requires `.listEntrance()` on the ScrollView). Prefer stable `id:` keys for mutable lists. Default timing is `easeOut` (no overshoot/bounce); pass `.easeOutBack` / `.spring` explicitly to opt into a rebound. |
| `RevealEffect` | ✅ Table / Collection | ✅ | Position; scale + fade in as cells enter the viewport |

Entry points:

| Entry | Platform | Family | Drives |
|------|------|------|------|
| `scrollView.entrance` | UIKit | `EntranceEffect` | `ListEffectEntrance` (CADisplayLink per-frame sampling; timing now in effect) |
| `scrollView.scrollEffect` | UIKit | `PositionEffect` | `PositionEffectDriver` (KVO on `contentOffset`) |
| `.entranceEffect(_:id:)` / `.entranceEffect(_:index:)` | SwiftUI | `EntranceEffect` | one-shot, real-visibility driven (+ `.listEntrance()` container for enter-once latch) |
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
ListEffectSwiftUI  ViewModifiers: .listEffect on .scrollTransition; .entranceEffect + .listEntrance on real scroll-geometry visibility with an enter-once coordinator (iOS 17+)
```

Effect **math** is decoupled from the **host control**: `SlideInEffect` / `RevealEffect` are pure functions (`resolve`) invoked by each platform's driver.

## License

MIT
