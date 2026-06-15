# Implementation Notes

## Changes

* Added a fixed thumbnail slot in `ItemCard` so card text and artwork spacing remain stable.
* Moved the footer row's trailing edge away from the thumbnail slot when a cover exists, preventing the estimated reading time from visually sitting under the thumbnail.
* Added document-style thumbnail treatment for PDF artwork: fit-mode image rendering, inner padding, stronger border, and subtle shadow.
* Kept non-document artwork on the existing fill-mode behavior.

## Verification

* `swift build` passed.
* `swift test` passed with 39 tests.
* `./script/build_and_run.sh --verify` passed and the app launched.
* Captured screenshots for visual inspection:
  * `/tmp/reader-item-card-fix.png`
  * `/tmp/reader-item-card-fix-all.png`

## Test Notes

* No unit test was added because the change is presentational SwiftUI layout/styling with no new data transformation or business logic.
