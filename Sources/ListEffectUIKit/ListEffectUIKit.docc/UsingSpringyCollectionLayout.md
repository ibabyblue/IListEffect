# Using a Springy Collection Layout

Use ``SpringyCollectionLayout`` as the collection view's layout to add inertial trailing and rebound.

```swift
import ListEffectUIKit

let layout = SpringyCollectionLayout()
layout.springFrequency = 2.2
layout.springDamping = 0.92
layout.scrollResistanceFactor = 3_000

let collectionView = UICollectionView(
    frame: .zero,
    collectionViewLayout: layout
)
```

Increase ``SpringyCollectionLayout/springDamping`` for less oscillation. Increase ``SpringyCollectionLayout/springFrequency`` for a faster, stiffer response. Increase ``SpringyCollectionLayout/scrollResistanceFactor`` for less displacement.
