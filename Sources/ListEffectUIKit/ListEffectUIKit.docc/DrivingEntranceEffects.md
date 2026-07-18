# Driving Entrance Effects

Attach an entrance effect once, animate the initial visible batch, and handle later cells as they appear.

```swift
import ListEffectCore
import ListEffectUIKit

tableView.entrance.attach(SlideInEffect())

override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    tableView.entrance.animateInitialBatch()
}

func tableView(
    _ tableView: UITableView,
    willDisplay cell: UITableViewCell,
    forRowAt indexPath: IndexPath
) {
    let item = items[indexPath.row]
    tableView.entrance.handle(cell: cell, id: item.id, indexPath: indexPath)
}
```

Prefer the stable `id:` overload for mutable lists. It keeps entrance state attached to business identity when rows are inserted, removed, or reordered. Call ``ListEffectEntrance/resetEnteredState()`` after intentionally replacing the entire data set and wanting to replay entrances.

> Important: The driver transforms the cell itself. Avoid competing transform or alpha animations on the same cell.
