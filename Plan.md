# Standby Project Plan

## 1. Project Overview

Standby is an iOS SwiftUI app that turns a device into a simple dark-mode standby clock. The current experience shows a large time and date display in landscape, applies small periodic drift to reduce burn-in risk, and uses front-camera face detection to hide the display when no user is present.

The app currently targets iOS 26.1 and uses Swift 6 for the app target.

## 2. Current Status

### Working

- Single app target: `Standby`.
- Test targets exist: `StandbyTests` and `StandbyUITests`.
- Main UI shows a large `HH:mm:ss` clock and Chinese date string.
- Display is forced into dark appearance.
- Landscape orientation is configured for iPhone.
- A drift timer moves the display slightly every minute.
- A schedule hides the display between 00:00 and 05:59.
- Camera metadata face detection is wired to `isUserPresent`.
- Debug simulator build succeeds with Xcode 26.5.
- Baseline before plan execution was clean on `main`.

### Known Gaps

- The screen-off schedule logic is embedded inside `StandbyMainView`, making it harder to test.
- Unit tests and UI tests are still mostly Xcode templates.
- Camera startup currently has minimal authorization/error handling.
- Camera session startup is synchronous in the view controller path.
- Location usage description exists in build settings but no location feature is present.
- App icon and accent color asset metadata exist, but the standard catalog entries do not reference image filenames or color values.
- Release device build requires a valid provisioning profile for `Martin.Standby`.

## 3. Product Goals

### Short Term

- Keep the app reliable as a passive clock.
- Make display visibility rules deterministic and testable.
- Improve camera permission and unavailable-camera behavior.
- Remove unused permissions before release.

### Medium Term

- Add a minimal settings surface for sleep hours and presence detection.
- Add display styles such as seconds on/off, date on/off, and brightness presets.
- Improve UI tests so launch and core text visibility are checked.

### Long Term

- Support multiple clock layouts.
- Add burn-in protection options.
- Consider widgets or Live Activity-style companions if they fit the product direction.

## 4. Roadmap

### Phase 1: Stabilize Clock Logic

- Extract the night screen-off schedule into a small testable type.
- Replace template unit tests with deterministic schedule tests.
- Keep default hidden hours as 00:00 through 05:59.

Acceptance criteria:

- Schedule behavior is covered by tests.
- App build and test targets compile after extraction.

### Phase 2: Harden Camera Presence Detection

- Request camera authorization explicitly before starting capture.
- Treat denied, restricted, or unavailable camera as a clear deterministic state.
- Start and stop the capture session off the main thread where appropriate.
- Avoid updating SwiftUI state from stale callbacks after teardown.

Acceptance criteria:

- The app handles missing camera permission without hanging.
- No main-thread capture-session startup warning is expected.
- Face detection still updates display presence state.

### Phase 3: Clean Project Configuration

- Remove unused location usage description if no location feature is planned.
- Decide whether iPad orientation behavior should match iPhone landscape-only behavior.
- Verify app icon and accent color assets before release.

Acceptance criteria:

- Privacy strings match actual app behavior.
- Release configuration is ready for archive once signing is available.

### Phase 4: Improve Tests

- Add UI test coverage for basic launch.
- Add accessibility identifiers for the clock and date text.
- Add tests for launch state where feasible.

Acceptance criteria:

- `xcodebuild test` runs the non-camera deterministic tests reliably.
- UI tests assert at least one user-visible clock element.

### Phase 5: User Controls

- Add settings for hidden hours.
- Add optional camera presence detection toggle.
- Add seconds/date visibility toggles.
- Persist settings with `AppStorage`.

Acceptance criteria:

- The app remains useful without needing code changes for common preferences.
- Defaults preserve the current behavior.

## 5. Technical Tasks

### Clock

- Keep formatting and schedule logic separated from SwiftUI rendering.
- Prefer deterministic calendar/date inputs for tests.
- Keep the display readable across compact and regular landscape widths.

### Camera

- Separate session lifecycle from UI state where possible.
- Keep permission handling explicit and user-facing.
- Avoid starting capture when the app is in a scheduled hidden state if this becomes a battery concern.

### Configuration

- Audit generated Info.plist keys.
- Keep only permissions used by code.
- Validate signing and provisioning outside simulator builds.

## 6. Risks

- Continuous camera usage can affect battery and privacy expectations.
- Face detection may be unreliable in low light or with device placement.
- Hiding the clock when no face is detected may surprise users if the camera cannot see them.
- Running camera code in simulator does not fully validate real-device behavior.

## 7. Verification Checklist

- Build Debug simulator:
  - `xcodebuild -project Standby.xcodeproj -scheme Standby -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Build Release simulator:
  - `xcodebuild -project Standby.xcodeproj -scheme Standby -configuration Release -destination 'generic/platform=iOS Simulator' build`
- Run unit tests:
  - `xcodebuild test -project Standby.xcodeproj -scheme Standby -destination 'platform=iOS Simulator,name=iPhone 17'`
- Manual real-device test:
  - Launch in landscape.
  - Confirm camera permission prompt copy.
  - Confirm clock shows when a face is visible.
  - Confirm display hides after face absence delay.
  - Confirm schedule hides display during configured night hours.

## 8. Suggested Next Step

Start with Phase 1. Extracting the clock schedule and replacing the template unit test gives the project a stable test baseline before changing camera behavior.
