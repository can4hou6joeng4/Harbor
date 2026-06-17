# GitHub Release Autoupdate Notes

## Implementation

- Sparkle is integrated as a SwiftPM binary dependency (`Sparkle` 2.9.3).
- `ReaderMacApp` owns an app-level `SPUStandardUpdaterController` and exposes a `Reader -> 检查更新...` menu action.
- `script/package_app.sh` embeds `Sparkle.framework` into `Contents/Frameworks`, adds `@executable_path/../Frameworks` as an rpath, signs Sparkle before signing the host app, and injects:
  - `SUFeedURL=https://raw.githubusercontent.com/can4hou6joeng4/ReaderMacApp/main/appcast.xml`
  - `SUPublicEDKey=p+KvvvIpXwMZlgzRUKd6kh/EnIt3UTVwbABgFp6Ah1Y=`
  - `SUEnableAutomaticChecks=true`
- `script/build_and_run.sh` mirrors the Sparkle framework embedding for local verify runs, with automatic checks disabled in the development bundle.
- Local ad-hoc hardened-runtime signing uses `com.apple.security.cs.disable-library-validation` so the app can load Sparkle's ad-hoc framework without a matching Team ID. This is part of the unsigned/free distribution route and should be revisited when moving to Developer ID signing.
- `.github/workflows/release.yml` builds on `macos-14`, packages `dist/Reader.dmg`, signs the DMG with Sparkle `sign_update`, creates the GitHub Release, then commits the updated `appcast.xml` back to `main`.
- `script/update_appcast.py` updates `appcast.xml` with one item per release and replaces duplicate version entries.

## EdDSA Key Handling

- Public key committed in scripts/docs: `p+KvvvIpXwMZlgzRUKd6kh/EnIt3UTVwbABgFp6Ah1Y=`.
- Private key generated with Sparkle `generate_keys --account com.bobochang.ReaderMacApp`.
- Private key exported only to a temporary file, then set with:

```bash
gh secret set SPARKLE_PRIVATE_KEY --repo can4hou6joeng4/ReaderMacApp < /tmp/readermacapp-sparkle-key
```

- The exported private key file is not committed and should be deleted after secret setup.

## Ad-hoc Distribution Boundary

- Gatekeeper quarantine remains expected for the first downloaded install because the app is not Developer ID signed or notarized.
- Sparkle EdDSA validates archive integrity, but Sparkle also performs code-signing validation between old and new app bundles. This project signs both old and new bundles ad-hoc with hardened runtime; if Sparkle rejects an installed update because ad-hoc signatures are not stable enough for its validation path, the supported fallback is manual DMG replacement from GitHub Releases.

## Validation Log

- Passed: `swift package resolve`
- Passed: `swift build`
- Passed: `swift test` (91 XCTest cases)
- Passed: `./script/build_and_run.sh --verify`
- Passed: `./script/package_app.sh`
- Passed: `/usr/libexec/PlistBuddy -c 'Print SUFeedURL' dist/Reader.app/Contents/Info.plist`
- Passed: `/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' dist/Reader.app/Contents/Info.plist`
- Passed: `/usr/libexec/PlistBuddy -c 'Print SUEnableAutomaticChecks' dist/Reader.app/Contents/Info.plist`
- Passed: `codesign --verify --strict --deep --verbose=4 dist/Reader.app`
- Passed: `hdiutil verify dist/Reader.dmg`
- Passed: mounted `dist/Reader.dmg` and confirmed `Reader.app` plus `Applications` symlink.
- Passed: `sign_update --ed-key-file <temp-private-key> dist/Reader.dmg`, then `sign_update --verify dist/Reader.dmg <signature>`.
- Passed: `script/update_appcast.py` generated an item with `sparkle:version`, `sparkle:shortVersionString`, `sparkle:minimumSystemVersion`, `enclosure url`, `sparkle:edSignature`, and `length`.
- Not manually clicked: Sparkle "check for updates" UI against the empty remote feed. `./script/build_and_run.sh --verify` confirms the app launches with Sparkle embedded and configured.
