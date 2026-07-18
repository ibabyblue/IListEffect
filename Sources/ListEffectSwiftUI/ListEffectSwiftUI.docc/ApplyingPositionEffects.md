# Applying Position Effects

Apply `listEffect(_:)` to each row inside a scroll container.

```swift
import ListEffectCore
import ListEffectSwiftUI
import SwiftUI

ScrollView {
    LazyVStack {
        ForEach(items) { item in
            RowView(item: item)
                .listEffect(RevealEffect(minScale: 0.8))
        }
    }
}
```

SwiftUI supplies the row's transition phase continuously, and IListEffect resolves it through the shared `PositionEffect` contract.
