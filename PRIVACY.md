# Privacy

Standby is designed to run locally on the device.

## Camera

The app uses the front camera for local face metadata detection through `AVCaptureMetadataOutput`. The camera feed is not shown in the UI, written to disk, uploaded, or sent to any server.

Face metadata is used only to decide whether the standby clock should be visible and when to rotate to the next clock face.

## Data Collection

Standby does not collect:

- Camera images or videos.
- Location data.
- Account information.
- Analytics events.
- Advertising identifiers.
- Network telemetry.

## Network

The app has no app-level networking feature.

## Permissions

Standby requests camera access because face presence detection requires the front camera. If camera access is denied or unavailable, the app falls back to keeping the clock visible.
