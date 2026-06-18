# Implementation Notes

## Changes

- Attached `.onboardingTarget(.addContent)` to the real top add `IconButton` in `SidebarView`.
- Split the AI onboarding targets into `.aiPanel` for the right AI tab bar and `.aiSettings` for the left-bottom gear.
- Reworked `OnboardingOverlay` to resolve one or more target frames, draw multiple transparent cutouts, and place the card against the union of visible cutouts.
- Moved the named onboarding coordinate space so it wraps both the measured app content and the overlay, then converts target frames from that same named space into the overlay drawing space.
- Removed the previous `.addContent` derived frame and all absolute add-button offset guesses.
- Added partial-target copy for responsive layouts where one target is hidden, such as the AI panel below the inline AI threshold.

## Verification

Commands run on 2026-06-18:

```bash
swift build
swift test
./script/build_and_run.sh --verify
```

Results:

- `swift build`: passed.
- `swift test`: passed, 94 tests.
- `./script/build_and_run.sh --verify`: passed and launched the packaged `dist/ReaderMacApp.app`.

Real `ContentView` validation:

- Reset onboarding with `defaults delete com.bobochang.ReaderMacApp ReaderStore.onboardingCompleted`.
- Launched the real packaged macOS app through `./script/build_and_run.sh --verify`.
- Advanced steps with System Events Return key and captured the live app window with `screencapture`.
- Final wide-window screenshots at 1540x920:
  - `/tmp/reader-onboarding-alignment-final/1540-step-1.png`
  - `/tmp/reader-onboarding-alignment-final/1540-step-2.png`
  - `/tmp/reader-onboarding-alignment-final/1540-step-3.png`
  - `/tmp/reader-onboarding-alignment-final/1540-step-4.png`
  - `/tmp/reader-onboarding-alignment-final/1540-step-5.png`
- Final compact-window screenshots at 1280x800:
  - `/tmp/reader-onboarding-alignment-final/1280-step-1.png`
  - `/tmp/reader-onboarding-alignment-final/1280-step-2.png`
  - `/tmp/reader-onboarding-alignment-final/1280-step-3.png`
  - `/tmp/reader-onboarding-alignment-final/1280-step-5.png`

Visual checks:

- 1540x920: step 2 precisely highlights the real top add `+` button; step 3 highlights the RSS section header including its `+`; step 5 highlights both the AI tab bar and left-bottom gear.
- 1540x920: sidebar and reader-panel steps remained aligned after the coordinate-space change.
- 1280x800: step 2 and step 3 remain aligned; step 5 highlights the visible gear and shows the partial-target notice because the right AI panel is hidden by the existing `inlineAIThreshold`.
