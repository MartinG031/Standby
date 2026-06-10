# Standby

Standby is a dark, landscape-first iOS clock app for a spare device on a desk or bedside table. It keeps the clock readable at a distance, hides during configured night hours, and uses local front-camera face metadata detection to dim the display when no one is present.

## Highlights

- Large `HH:mm:ss` SwiftUI clock with Chinese date and weekday.
- Four rotating clock faces: Classic, Orbit, Horizon, and Focus.
- Face-detection wake behavior: each return from absent to present advances to a different clock face.
- Full-screen dark backgrounds designed for landscape standby use and notch concealment.
- Small periodic clock drift to reduce burn-in risk without moving the full-screen background.
- Scheduled display hiding from 00:00 through 05:59.
- Front-camera presence detection using local `AVCaptureMetadataOutput` face metadata only.
- Camera session start/stop is kept off the main thread where appropriate for modern Swift concurrency and SDK behavior.
- The app keeps the device awake while the standby view is active.

## Privacy

Standby uses the front camera only for local face metadata detection. It does not capture, save, upload, or display camera images.

The app does not use location services, networking, analytics, accounts, ads, or third-party tracking SDKs.

See [PRIVACY.md](PRIVACY.md) for the project privacy note.

## Requirements

- Xcode 26.5 or newer.
- iOS 26.1 deployment target.
- Swift 6.

Xcode 27 / iOS 27 compatibility work has started by keeping capture-session work off the main thread, returning UI state updates to the main actor, and avoiding simulator-only camera assumptions.

## Build

```sh
xcodebuild \
  -project Standby.xcodeproj \
  -scheme Standby \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## Test

Unit tests cover deterministic schedule behavior and clock-face cycling:

```sh
xcodebuild test \
  -project Standby.xcodeproj \
  -scheme Standby \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

For simulator UI tests, launch with `STANDBY_DISABLE_NIGHT_HIDE=1` when you need a stable visible clock outside the real night-hide schedule.

## Real-Device Checks

Face detection should be validated on a real iPhone because iOS Simulator may not expose a front camera.

Before release, verify:

- Landscape launch and safe-area behavior on notched devices.
- Camera permission prompt and denied-permission fallback.
- Clock hides after face absence and returns when a face is visible.
- Clock face changes after a return from absent to present.
- 00:00-05:59 scheduled hiding.
- Long-running standby behavior while plugged in.

## Project Layout

```text
Standby/
  ContentView.swift          Main SwiftUI UI, clock faces, and camera presence bridge
  StandbySchedule.swift      Testable display-hide schedule
  StandbyApp.swift           App entry point
StandbyTests/
  StandbyTests.swift         Deterministic schedule and style-cycle tests
StandbyUITests/
  StandbyUITests.swift       Basic launch UI tests
Plan.md                      Roadmap and verification checklist
```

## Roadmap

Current focus:

- Polish real-device landscape behavior.
- Keep camera presence detection reliable without simulator-only assumptions.
- Improve release readiness documentation.
- Add settings for hidden hours, presence detection, and clock display options.

See [Plan.md](Plan.md) for the full roadmap.

## Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening larger changes.

## License

No open-source license has been selected yet. Until a license is added, all rights are reserved by the repository owner.
