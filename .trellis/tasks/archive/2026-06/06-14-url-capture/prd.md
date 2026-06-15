# URL 采集

## Goal

Implement Task C from `.trellis/spec/guides/content-capture-design.md` so URL capture becomes real: a user can paste an article URL, fetch and extract readable content, preview it, save it locally, and see the saved item survive restart. Include the two carry-over fixes from section 8.

## Requirements

* Add the content capture layer in `ReaderCore/Capture/`: `HTTPClient`, `ContentExtractor`/`SwiftSoupExtractor`, and `CaptureService`.
* Add SwiftSoup to `ReaderCore`; keep SwiftSoup and all network access out of the UI target.
* Add schema v2 exactly as specified by the design guide, without modifying the existing v1 migration.
* Extend `ReaderItem`, `Feed`, `LibrarySnapshot`, `GRDBRepository`, and `InMemoryRepository` for `url`, `guid`, `coverPath`, and feed v2 metadata where Task C needs persistence.
* Wire AddContentModal's URL tab through `ReaderStore` to the real capture flow: loading state, real preview, save to repository, and user-visible failure feedback.
* Download only the cover image when `og:image` exists; store it under `Attachments/<uuid>.<ext>` and render it in list thumbnails and the reader hero before falling back to `CoverGradient`.
* Do not silently save an empty article. Extraction below the configured body threshold must fail with a clear UI message.
* Implement section 8 carry-over fixes: alert/log on GRDB fallback to `InMemoryRepository`, and phrase-style FTS behavior for Chinese phrase searches.

## Acceptance Criteria

* [x] Pasting a real article URL can fetch, preview, save, and reload after app restart.
* [x] Extraction failure produces explicit feedback and does not create an empty item.
* [x] Unit tests cover the extraction pipeline with at least three real webpage fixtures: Chinese blog, English longform, and a page with `og:image`.
* [x] Migration v2 has test coverage and does not modify the v1 migration block.
* [x] FTS test proves searching `本地优先` does not match a document where the four characters are dispersed rather than consecutive.
* [x] Tests use mock `HTTPClient` and fixtures only; no test performs real network I/O.
* [x] `swift build`, `swift test`, and `./script/build_and_run.sh --verify` pass or any non-pass is documented with the exact blocker.

## Definition of Done

* Tests added or updated for extraction, capture service behavior, persistence, and the FTS carry-over fix.
* Capture services depend on `ReaderRepository`, not GRDB.
* View layer and app target do not import SwiftSoup.
* User-facing failure paths cover timeout/network failure, non-HTML responses, and extraction failure.
* The implementation preserves the documented out-of-scope boundary: no X, Weibo, YouTube, RSS sync, attachment import, JS-rendered page fallback, or body-image downloading in Task C.

## Technical Approach

Follow `.trellis/spec/guides/content-capture-design.md` sections 3, 5, 8, 9, and 11 directly. The cross-layer flow is:

`AddContentModal -> ReaderStore -> CaptureService -> HTTPClient -> SwiftSoupExtractor -> ReaderRepository -> ReaderStore snapshot -> list/detail UI`.

`CaptureService` owns URL validation, fetch orchestration, language/read-time metadata, optional cover download, and construction of a `ReaderItem`. `SwiftSoupExtractor` owns HTML cleanup, readable block selection, metadata extraction, and `[ContentBlock]` mapping. `URLSessionHTTPClient` is the only real network implementation. Tests inject fixture-backed `HTTPClient`.

## Decision (ADR-lite)

**Context**: The binding design guide already chooses SwiftSoup and the local repository boundary, so there is no open library or architecture decision for Task C.

**Decision**: Implement the documented native Swift capture layer and keep future JS-rendered extraction behind the `ContentExtractor` protocol without adding that fallback now.

**Consequences**: Static HTML article pages are covered by a testable pipeline. JS-only pages can fail clearly in this milestone rather than introducing a main-thread WebView or unstable scraper.

## Out of Scope

* RSS/Atom sync and subscription management wiring; that is Task D.
* PDF/image/video attachment import; that is Task E.
* X, Weibo, and YouTube real capture.
* Offline downloading of images inside the article body.
* JS-rendered webpage extraction.
* Real AI integration.

## Technical Notes

* Binding design: `.trellis/spec/guides/content-capture-design.md`.
* Persistence constraints: `.trellis/spec/guides/persistence-design.md`.
* Cross-layer checklist applied because the task spans Capture services, repository/schema, Store, and SwiftUI views.
* Existing URL path to replace: `ReaderStore.addItem(from:)` currently fabricates web content.
* Existing UI path to wire: `Sources/ReaderMacApp/Views/OverlaysView.swift` URL tab.
* Existing cover rendering paths: `Sources/ReaderMacApp/Views/ItemListView.swift`, `Sources/ReaderMacApp/Views/ReaderDetailView.swift`, and `Sources/ReaderMacApp/Support/CoverGradient.swift`.
* Existing GRDB fallback path: `Sources/ReaderMacApp/App/ReaderMacApp.swift`.
* Existing FTS query path: `Sources/ReaderCore/Persistence/GRDBRepository.swift`.
