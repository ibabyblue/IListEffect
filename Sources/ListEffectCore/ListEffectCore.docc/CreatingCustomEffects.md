# Creating Custom Effects

Create reusable effects by returning an ``EffectOutput`` from one of the core protocols.

## Create a Position Effect

The following effect fades items toward either viewport edge:

```swift
import ListEffectCore

struct FadeEdgesEffect: PositionEffect {
    func resolve(position: CGFloat) -> EffectOutput {
        EffectOutput(alpha: 1 - min(1, abs(position)))
    }
}
```

## Create an Entrance Effect

An entrance effect also supplies the duration used by platform drivers:

```swift
import ListEffectCore

struct FadeInEffect: EntranceEffect {
    let duration: TimeInterval = 0.35

    func resolve(progress: CGFloat) -> EffectOutput {
        EffectOutput(alpha: progress)
    }
}
```

Keep effect resolution free of UI state. This lets UIKit and SwiftUI share the same math and makes endpoint behavior easy to test.
