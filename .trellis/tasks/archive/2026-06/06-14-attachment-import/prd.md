# 附件导入

## Goal

Implement Task E from `.trellis/spec/guides/content-capture-design.md`: the AddContentModal attachment tab can import local PDF/image/video files into `Attachments/`, persist them, and make PDF text searchable.

## Requirements

* Add `AttachmentImporter` under `ReaderCore/Capture/`.
* Copy selected files into `Attachments/<uuid>.<ext>`; never reference the original file path.
* PDF import uses PDFKit to extract text page by page, one paragraph block per non-empty page.
* PDF reading time is estimated at 400 characters per minute.
* PDF first page thumbnail is rendered and stored as `cover_path` when available.
* Image import stores the original file as the cover, creates one image block, and persists `attachment_path` and `cover_path`.
* Video import stores the original file and duration via `AVURLAsset.duration`; no transcoding or subtitles.
* Wire AddContentModal attachment tab to `NSOpenPanel` selection and drag/drop where practical.
* Save imported items through `ReaderStore` and `ReaderRepository` so they survive restart and are searchable through existing FTS.

## Acceptance Criteria

* [x] Selecting/importing a PDF produces a saved item whose extracted text is readable and searchable by FTS.
* [x] Reopening the database preserves the imported PDF item and attachment path.
* [x] Fixture test generates a small PDF inside the test temp directory and verifies import + FTS.
* [x] Image import stores the image as cover and body image block.
* [x] `swift build`, `swift test`, and `./script/build_and_run.sh --verify` pass or any non-pass is documented with the exact blocker.

## Definition of Done

* Importer does not touch user source files except reading them.
* Tests use temporary directories and generated fixtures only.
* UI target does not import PDFKit/AVFoundation for core import logic; file picking UI stays in app target.
* Out-of-scope video processing remains excluded.

## Technical Approach

Follow `.trellis/spec/guides/content-capture-design.md` sections 7, 9, and 11. The flow is:

`AddContentModal attachment tab -> NSOpenPanel/drop URL -> ReaderStore -> AttachmentImporter -> copied file/thumbnail -> ReaderRepository.saveItem -> FTS`.

The importer returns a fully formed `ReaderItem`; `ReaderStore` handles selection, toast, and local list update.

## Out of Scope

* OCR for image-only PDFs.
* Video transcoding, subtitles, and previews beyond duration metadata.
* OPML and feed work.

## Technical Notes

* Attachment root must match persistence design: Application Support `ReaderMacApp/Attachments`.
* Existing `coverPath` rendering from Task C should be reused.
* Existing FTS indexing already indexes `ContentBlock.text`, so PDF text should become searchable through `saveItem`.
