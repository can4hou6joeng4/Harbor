# Database Guidelines

> Database patterns and conventions for this project.

---

## Overview

<!--
Document your project's database conventions here.

Questions to answer:
- What ORM/query library do you use?
- How are migrations managed?
- What are the naming conventions for tables/columns?
- How do you handle transactions?
-->

(To be filled by the team)

---

## Query Patterns

<!-- How should queries be written? Batch operations? -->

(To be filled by the team)

---

## Migrations

<!-- How to create and run migrations -->

(To be filled by the team)

---

## Naming Conventions

<!-- Table names, column names, index names -->

(To be filled by the team)

---

## Common Mistakes

<!-- Database-related mistakes your team has made -->

## Scenario: Reader persistence v1

### 1. Scope / Trigger

- Trigger: any local persistence/storage work in ReaderCore.
- Binding guide: `.trellis/spec/guides/persistence-design.md`.
- Implementation boundary: `ReaderCore/Persistence/GRDBRepository.swift` is the only production file that imports GRDB.

### 2. Signatures

- Dependency: `ReaderCore` depends on `GRDB` from `https://github.com/groue/GRDB.swift.git`, `from: "6.0.0"`.
- Public protocol: `ReaderRepository` with async methods for `loadLibrary`, `saveItem`, `deleteItem`, `setItemFlags`, `saveHighlights`, `saveReadingState`, and `search`.
- DB migration entrypoint: `Migrations.migrator()` registers schema migration `v1`.

### 3. Contracts

- File-backed DB path: `~/Library/Application Support/ReaderMacApp/reader.sqlite`; never hardcode an absolute path.
- Attachment root: `~/Library/Application Support/ReaderMacApp/Attachments/`; DB stores only relative attachment paths.
- Tests must use temporary file databases or in-memory `DatabaseQueue()`.
- On first repository initialization, seed from `SampleLibrary` only when `item` is empty.
- `ReaderItem.publishedAt` is persisted as `Date.timeIntervalSince1970`.

### 4. Validation & Error Matrix

- Empty query -> return an empty search result.
- Missing item for flag/highlight/reading-state updates -> no-op.
- Invalid persisted highlight UUID -> throw a persistence error.
- Malformed JSON in `body_json` or `summary_json` -> throw decoding error.

### 5. Good/Base/Bad Cases

- Good: `GRDBRepository` handles schema migration, seeding, FTS indexing, and snapshot reconstruction behind `ReaderRepository`.
- Base: `InMemoryRepository` keeps matching semantics for previews and tests.
- Bad: importing GRDB from ReaderStore or SwiftUI views.
- Bad: adding a `ContentBlock` table; body content is stored as JSON and indexed into FTS text.

### 6. Tests Required

- Empty database migrates successfully.
- Seeded file database can be reopened with data intact.
- Item, highlight, tag, body JSON, and summary JSON round-trip.
- FTS search matches English and Chinese content.
- Deleting an item cascades highlights and item-tag rows.

### 7. Wrong vs Correct

#### Wrong

```swift
// UI or ReaderStore layer
import GRDB
```

#### Correct

```swift
public protocol ReaderRepository: Sendable {
    func loadLibrary() async throws -> LibrarySnapshot
    func search(_ query: String) async throws -> [String]
}
```

### Implementation Notes

- Keep the documented contentless FTS5 table shape and join `item_fts.rowid` back to `item.rowid` to return item IDs.
- Because `body_text` is derived from decoded `body_json`, repository code must update/delete the FTS payload when saving or deleting an item.
- Normalize CJK text and CJK queries before FTS by spacing CJK scalars; local SQLite `unicode61` did not match CJK substrings reliably without this preprocessing.

## Scenario: Reader content capture v2

### 1. Scope / Trigger

- Trigger: URL capture, RSS sync, or attachment import work that writes captured content into ReaderCore persistence.
- Binding guide: `.trellis/spec/guides/content-capture-design.md`.
- Implementation boundary: network/parsing/import services live under `ReaderCore/Capture/`; SwiftUI views must call them through `ReaderStore`.

### 2. Signatures

- Migration: `Migrations.migrator()` appends `v2`; do not edit `v1`.
- Item fields added by v2: `url`, `guid`, `cover_path`.
- Feed fields added by v2: `last_fetched_at`, `etag`, `last_modified`.
- Unique index: `item_feed_guid_idx ON item(feed_id, guid) WHERE guid IS NOT NULL`.
- Repository API includes `saveFeed`, `updateFeedMetadata`, and `containsItem(feedID:guid:)` in addition to v1 item APIs.

### 3. Contracts

- DB stores attachment/cover paths as relative `Attachments/<uuid>.<ext>` strings.
- URL capture and RSS sync must fetch through `HTTPClient`; tests must inject fixture-backed mocks.
- Capture services save or return `ReaderItem` values and persist through `ReaderRepository`; they must not import GRDB.
- UI target must not import SwiftSoup, FeedKit, PDFKit, AVFoundation, or GRDB for core parsing/import logic.
- New RSS subscriptions may fetch once to parse the feed title, but must not persist `etag` or `last_modified` from that title probe; validators are only saved after the first real sync attempt, otherwise the immediate initial sync can get 304 and insert no items.

### 4. Validation & Error Matrix

- Non-HTML URL capture response -> user-visible capture error, no empty item saved.
- Extracted URL body below threshold -> user-visible extraction error, no empty item saved.
- RSS 304 -> update `last_fetched_at`, skip parsing and item writes.
- First RSS sync after add -> no conditional headers from the title probe, so the first sync can insert entries before validators are stored.
- Duplicate RSS `feed_id` + `guid` -> skip insert; never overwrite existing user state.
- Unsupported attachment extension -> user-visible import error.
- PDF with no extractable text -> save an item with fallback body text, but do not invent OCR.

### 5. Good/Base/Bad Cases

- Good: `ReaderStore -> Capture/Feed/Attachment service -> ReaderRepository -> GRDBRepository` with UI state updated after success.
- Base: `InMemoryRepository` mirrors feed metadata and item semantics for previews/tests.
- Bad: SwiftUI view directly importing SwiftSoup/FeedKit/PDFKit/AVFoundation for core work.
- Bad: tests using real network or user Application Support paths.

### 6. Tests Required

- URL extraction fixtures for Chinese, English, and `og:image` pages.
- Migration v2 columns/index test.
- RSS/Atom fixture tests for parsing, guid fallback, 304, duplicate skip, and failure isolation.
- Attachment tests using generated temp PDF/image files; PDF text must be searchable through repository FTS.
- Boundary check with `rg` to ensure UI/store do not import parser/import frameworks directly.

### 7. Wrong vs Correct

#### Wrong

```swift
// SwiftUI layer
import FeedKit
import SwiftSoup
```

#### Correct

```swift
// SwiftUI layer
Task {
    await store.addRSSFeed(urlString)
}
```

```swift
// ReaderCore/Capture
let response = try await httpClient.fetch(CaptureRequest(url: feedURL))
let parsed = FeedParser(data: response.data).parse()
```
