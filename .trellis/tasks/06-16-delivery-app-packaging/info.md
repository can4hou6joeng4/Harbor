# Implementation Notes

## Package Output

- Command: `./script/package_app.sh --regenerate-icon`
- App bundle: `dist/Reader.app`
- Disk image: `dist/Reader.dmg`
- Display name: `Reader`
- Executable: `ReaderMacApp`
- Bundle identifier: `com.bobochang.ReaderMacApp`
- Version: `0.1.0`
- Build number source: `git rev-list --count HEAD`

## Signing And Sandbox Decision

- Default signing mode: ad-hoc (`SIGN_IDENTITY=-`) with hardened runtime (`codesign --options runtime --timestamp=none`).
- Default sandbox mode: disabled (`ENABLE_APP_SANDBOX=0`).
- Reason: this machine has no Developer ID identity, and ad-hoc + app sandbox was empirically unsafe for Keychain.
- Sandbox template retained at `Resources/Reader.entitlements` with:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.network.client`
  - `com.apple.security.files.user-selected.read-write`
- Optional sandbox attempt: run `ENABLE_APP_SANDBOX=1 ./script/package_app.sh` after a real signing identity/provisioning setup is available.

## Verification Evidence

- `./script/package_app.sh --regenerate-icon` passed:
  - release build completed
  - `dist/Reader.app` assembled
  - `codesign --verify --strict dist/Reader.app` passed
  - `codesign -dvvv --entitlements :- dist/Reader.app` showed `Signature=adhoc`, runtime flag, network client, and user-selected read-write entitlements
  - `dist/Reader.dmg` created and `hdiutil verify` reported checksum valid
- `plutil -p dist/Reader.app/Contents/Info.plist` confirmed required bundle fields:
  - `CFBundleExecutable=ReaderMacApp`
  - `CFBundleIdentifier=com.bobochang.ReaderMacApp`
  - `CFBundleDisplayName=Reader`
  - `CFBundleIconFile=AppIcon`
  - `LSMinimumSystemVersion=13.0`
  - `LSApplicationCategoryType=public.app-category.news`
- Icon verification:
  - `Resources/AppIcon.icns` generated from `script/make_app_icon.swift`
  - copied into `dist/Reader.app/Contents/Resources/AppIcon.icns`
  - `file` reported both as Mac OS X icon files
- Launch verification:
  - `open -n dist/Reader.app`
  - `pgrep -x ReaderMacApp` returned a live process
- DMG verification:
  - Mounted `dist/Reader.dmg`
  - `/Volumes/Reader` contained `Reader.app`
  - `/Volumes/Reader/Applications` was a symlink to `/Applications`
- Database verification:
  - Non-sandbox app launch used `~/Library/Application Support/ReaderMacApp`
  - `reader.sqlite`, `reader.sqlite-wal`, and `reader.sqlite-shm` were present after launch
- Keychain verification:
  - A temporary Swift generic-password round-trip signed with `Resources/Reader.entitlements` (ad-hoc + app sandbox) crashed with `Trace/BPT trap: 5`, matching the known sandbox/ad-hoc risk.
  - The same temporary program signed with the default local non-sandbox entitlements succeeded:
    - `addStatus=0`
    - `copyStatus=0`
    - `value=secret`
- AI network verification:
  - Real provider call was not executed in this session because no task-specific credential was injected for the packaged app.
  - Packaging keeps network client entitlement in both sandbox template and local signing entitlements; app-level AI network behavior remains covered by existing mock/unit tests and prior real endpoint work.

## Project Checks

- `swift build` passed.
- `swift test` passed: 91 tests, 0 failures.
- `./script/build_and_run.sh --verify` passed.

