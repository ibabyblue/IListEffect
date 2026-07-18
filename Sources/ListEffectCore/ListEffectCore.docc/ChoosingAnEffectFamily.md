# Choosing an Effect Family

Choose an effect protocol from the value that should drive the animation.

## Position Effects

A ``PositionEffect`` receives an item's normalized location in the viewport. Position `0` is centered, while values near `-1` and `1` represent opposite edges. Use this family for continuous effects that follow scrolling, such as ``RevealEffect``.

```swift
let output = RevealEffect(minScale: 0.82).resolve(position: 0.5)
```

## Entrance Effects

An ``EntranceEffect`` receives progress from `0` to `1` and declares its own duration. Use this family for one-shot effects, such as ``SlideInEffect``, that settle when an item first becomes visible.

```swift
let effect = SlideInEffect(amplitude: 180, duration: 0.45)
let initial = effect.resolve(progress: 0)
let settled = effect.resolve(progress: 1)
```

The platform integrations own visibility, scheduling, and applying the resulting ``EffectOutput``.
