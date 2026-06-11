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
