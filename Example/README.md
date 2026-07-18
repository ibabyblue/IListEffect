# IListEffect Example

This iOS app is the runnable integration catalog for IListEffect. It consumes the repository through a local Swift package dependency and demonstrates:

- `SpringyCollectionLayout` with UIKit Dynamics.
- `SlideInEffect` with the UIKit entrance driver.
- `RevealEffect` with the UIKit position driver.
- `RevealEffect` with SwiftUI `listEffect(_:)`.

## Generate the Project

The XcodeGen specification is the source of truth. Regenerate the checked-in project after changing targets, sources, or schemes:

```bash
xcodegen generate --spec Example/project.yml --project Example
```

## Build and Test

```bash
xcodebuild -quiet build \
  -project Example/IListEffectDemo.xcodeproj \
  -scheme IListEffectDemo \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -quiet test \
  -project Example/IListEffectDemo.xcodeproj \
  -scheme IListEffectDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```
