# Driving Position Effects

Attach a position effect to keep visible cells synchronized with scrolling.

```swift
import ListEffectCore
import ListEffectUIKit

tableView.scrollEffect.attach(RevealEffect(minScale: 0.8))
```

The driver observes `contentOffset` and does not take over the scroll view's delegate. When visible cells change without a scroll event, refresh them after layout:

```swift
tableView.reloadData()
tableView.layoutIfNeeded()
tableView.scrollEffect.applyNow()
```

Call ``PositionEffectDriver/detach()`` to stop observation and restore visible cells.
