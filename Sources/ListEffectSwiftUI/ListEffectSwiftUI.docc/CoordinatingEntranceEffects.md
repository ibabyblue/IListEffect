# Coordinating Entrance Effects

Install `listEntrance()` on the scroll container and apply `entranceEffect(_:id:)` to each row.

```swift
import ListEffectCore
import ListEffectSwiftUI
import SwiftUI

ScrollView {
    LazyVStack {
        ForEach(items) { item in
            RowView(item: item)
                .entranceEffect(SlideInEffect(), id: item.id)
        }
    }
}
.listEntrance()
```

The container measures the real viewport and coordinates identities across lazily rebuilt rows. A stable business identity ensures that insertion, deletion, or reordering does not replay the wrong row.

Use the `index:` overload only for static lists whose row identity is genuinely positional. Without `listEntrance()`, entrance modifiers fall back to instance-local `onAppear` behavior.
