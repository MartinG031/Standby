# Standby Project Plan

## 1. Project Overview

Standby is an iOS SwiftUI app that turns a device into a dark, landscape-first standby clock. The current experience shows a large time and date display over randomized solid or gradient backgrounds, applies small content drift to reduce burn-in risk, and uses front-camera face metadata detection to hide the display when no user is present.

The app currently targets iOS 26.1 and uses Swift 6 for the app target.

## 2. Current Status

### Working

- Single app target: `Standby`.
- Test targets exist: `StandbyTests` and `StandbyUITests`.
- Main UI shows a large `HH:mm:ss` clock and Chinese date string.
- Pure black and visibly fluid mesh-color backgrounds are available.
- The palette, flow direction, speed, and phase change whenever the user returns from absent to present.
- Display is forced into dark appearance.
- Landscape orientation is configured for iPhone.
- Content drifts slightly every minute while the full-screen background remains fixed.
- A schedule hides the display between 00:00 and 05:59.
- Camera metadata face detection is wired to `isUserPresent`.
- Camera session lifecycle is coordinated off the main thread where appropriate.
- Backgrounds use dark edge shading to reduce notch and rounded-corner visibility in landscape.
- Debug simulator build succeeds with Xcode 26.5.

### Known Gaps

- Real camera behavior still needs repeated device validation because simulator camera behavior is limited.
- UI tests cover basic launch but do not validate the real camera presence workflow.
- There is not yet a settings surface for schedule, seconds visibility, or presence detection.
- App icon and accent color asset metadata exist, but the standard catalog entries do not reference image filenames or color values.
- Release device build requires a valid provisioning profile for `Martin.Standby`.
- No open-source license has been selected yet.

## 3. Product Goals

### Short Term

- Keep the app reliable as a passive clock.
- Keep display visibility rules deterministic and testable.
- Continue validating camera permission and unavailable-camera behavior.
- Polish real-device landscape presentation, especially notched devices.

### Medium Term

- Add a minimal settings surface for sleep hours and presence detection.
- Add display options such as seconds on/off, date on/off, and brightness presets.
- Improve UI tests so launch and core text visibility are checked reliably.

### Long Term

- Add more clock layouts.
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

Status: Completed.

### Phase 2: Harden Camera Presence Detection

- Request camera authorization explicitly before starting capture.
- Treat denied, restricted, or unavailable camera as a deterministic visible-clock fallback.
- Start and stop the capture session off the main thread where appropriate.
- Avoid updating SwiftUI state from stale callbacks after teardown.

Acceptance criteria:

- The app handles missing camera permission without hanging.
- No main-thread capture-session startup warning is expected.
- Face detection still updates display presence state.

Status: Mostly completed. Continue validating on real devices.

### Phase 3: Polish Standby Presentation

- Add multiple background palettes.
- Randomize backgrounds when a user returns after absence.
- Keep all backgrounds full-screen and fixed while only content drifts.
- Make background edges dark enough to reduce notch and rounded-corner visibility.

Acceptance criteria:

- Each face remains readable in compact and regular landscape widths.
- Content drift does not expose unpainted edges.
- Notched-device landscape checks do not show bright background behind the notch.

Status: In progress. Real-device visual validation is still needed.

### Phase 4: Clean Project Configuration

- Remove unused generated Info.plist keys if any appear during release checks.
- Decide whether iPad orientation behavior should match iPhone landscape-only behavior.
- Verify app icon and accent color assets before release.
- Choose and add an open-source license if public reuse is intended.

Acceptance criteria:

- Privacy strings match actual app behavior.
- Release configuration is ready for archive once signing is available.
- Repository license state is explicit.

### Phase 5: Improve Tests

- Keep deterministic tests for the schedule and clock-face cycling.
- Add UI test coverage for basic launch.
- Add accessibility identifiers for the clock and date text.
- Add tests for launch state where feasible.

Acceptance criteria:

- `xcodebuild test` runs the non-camera deterministic tests reliably.
- UI tests assert at least one user-visible clock element.

Status: Partially completed.

### Phase 6: User Controls

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

- Keep session lifecycle separate from SwiftUI state where possible.
- Keep permission handling explicit and user-facing.
- Avoid starting capture when the app is in a scheduled hidden state if this becomes a battery concern.
- Validate real-device behavior whenever camera lifecycle changes.

### Presentation

- Keep colored background energy away from the notch and rounded-corner areas.
- Move only foreground clock content for burn-in protection.
- Keep randomized backgrounds visually distinct while preserving low-light readability.

### Configuration

- Audit generated Info.plist keys.
- Keep only permissions used by code.
- Validate signing and provisioning outside simulator builds.

## 6. Risks

- Continuous camera usage can affect battery and privacy expectations.
- Face detection may be unreliable in low light or with device placement.
- Hiding the clock when no face is detected may surprise users if the camera cannot see them.
- Running camera code in simulator does not fully validate real-device behavior.
- Bright standby backgrounds can make the notch or rounded display corners more visible.

## 7. Verification Checklist

- Build Debug simulator:
  - `xcodebuild -project Standby.xcodeproj -scheme Standby -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Build Release simulator:
  - `xcodebuild -project Standby.xcodeproj -scheme Standby -configuration Release -destination 'generic/platform=iOS Simulator' build`
- Run unit and UI tests:
  - `xcodebuild test -project Standby.xcodeproj -scheme Standby -destination 'platform=iOS Simulator,name=iPhone 17'`
- Manual real-device test:
  - Launch in landscape.
  - Confirm camera permission prompt copy.
  - Confirm clock shows when a face is visible.
  - Confirm display hides after face absence delay.
  - Confirm face return shows the clock and advances to a different face.
  - Confirm schedule hides display during configured night hours.
  - Confirm background edges remain dark enough that the notch is not visually emphasized.

## 8. Suggested Next Step

Run the app on a notched physical iPhone in landscape, validate the current backgrounds, then add a minimal settings surface for sleep hours and presence detection.
