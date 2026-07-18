# ``ListEffectCore``

Define platform-independent scroll and entrance effects once, then use them from UIKit or SwiftUI.

## Overview

`ListEffectCore` contains the shared effect contracts and visual output model. It has no UIKit or SwiftUI dependency, so custom effects remain small, deterministic value resolvers that are straightforward to test.

Use ``PositionEffect`` for values driven continuously by viewport position. Use ``EntranceEffect`` for one-shot animations driven from initial progress to a settled state.

## Topics

### Effect Contracts

- ``PositionEffect``
- ``EntranceEffect``

### Effect Output

- ``EffectOutput``
- ``RotationAxis``
- ``AnchorPoint``

### Built-in Effects

- ``RevealEffect``
- ``SlideInEffect``

### Guides

- <doc:ChoosingAnEffectFamily>
- <doc:CreatingCustomEffects>
