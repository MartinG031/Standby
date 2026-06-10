# Contributing

Thanks for helping improve Standby.

## Development

Use Xcode 26.5 or newer and keep changes compatible with the current Swift 6 project settings.

Build before opening a pull request:

```sh
xcodebuild \
  -project Standby.xcodeproj \
  -scheme Standby \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Run tests when changing schedule logic, UI identifiers, or behavior that can be tested without a real camera:

```sh
xcodebuild test \
  -project Standby.xcodeproj \
  -scheme Standby \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Pull Requests

Please include:

- What changed.
- Why the change is needed.
- How it was tested.
- Any real-device camera or notched-device checks, when relevant.

## Camera Behavior

Do not remove the face-detection path when changing UI or layout code. Simulator builds may not validate the camera path fully, so camera lifecycle changes should include real-device notes when possible.

## Style

- Prefer small SwiftUI views and local state.
- Keep schedule and formatting logic deterministic and testable.
- Avoid adding third-party dependencies unless the benefit is clear.
- Keep standby backgrounds dark near device edges so notches and rounded corners are less visible.
