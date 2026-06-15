# Implementation Notes

## Verification

* `swift build` passed in final closeout.
* `swift test` passed in final closeout with 39 tests.
* `./script/build_and_run.sh --verify` passed in final closeout.
* Boundary check: UI and `ReaderStore` do not import PDFKit, AVFoundation, FeedKit, SwiftSoup, or GRDB.
* Test fixture check: PDF fixture is generated in a temporary directory; no user directory is touched.

## Manual Verification

* Generated a real searchable PDF containing `Reader smoke PDF unique phrase alpha zeta`.
* Imported the PDF through the public `AttachmentImporter` and `GRDBRepository` path into the app's real local database after drag/file-picker automation proved unreliable in the macOS UI.
* The import copied the PDF into `Attachments/`, generated a cover thumbnail under `Attachments/`, and persisted a PDF `ReaderItem`.
* FTS query matched the unique PDF phrase.
* After killing and reopening the app, the PDF item and cover thumbnail were visible.
* In-app search for `Reader smoke PDF unique phrase alpha zeta` filtered the list to the imported PDF item.
