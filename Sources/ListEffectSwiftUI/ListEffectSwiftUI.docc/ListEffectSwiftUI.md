# ``ListEffectSwiftUI``

Apply scroll-linked and one-shot list effects with SwiftUI view modifiers.

## Overview

`ListEffectSwiftUI` maps the shared `ListEffectCore` contracts to SwiftUI. Position effects use `scrollTransition`; coordinated entrance effects use real viewport geometry and stable item identity.

These APIs require iOS 17 or macOS 14.

## Topics

### Position Effects

- ``SwiftUICore/View/listEffect(_:)``
- <doc:ApplyingPositionEffects>

### Entrance Effects

- ``SwiftUICore/View/listEntrance(perRowDelay:delayRowCap:)``
- ``SwiftUICore/View/entranceEffect(_:id:perRowDelay:delayRowCap:)``
- ``SwiftUICore/View/entranceEffect(_:index:perRowDelay:delayRowCap:)``
- <doc:CoordinatingEntranceEffects>
