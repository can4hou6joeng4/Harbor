# 持久化基座

## Goal

Implement Task A from `.trellis/spec/guides/persistence-design.md` section 8: add the local SQLite/GRDB persistence foundation for ReaderCore without wiring ReaderStore to it yet.

## Binding Design

- `.trellis/spec/guides/persistence-design.md` is authoritative for this task.
- Implement the Task A scope from section 8.
- Follow sections 1-7 for technical decisions and section 10 for self-checks that apply before ReaderStore wiring.

## Requirements

- Add GRDB.swift to `Package.swift` and depend on it from `ReaderCore` only.
- Add `ReaderRepository` async protocol, `GRDBRepository`, `InMemoryRepository`, and `Migrations` under `Sources/ReaderCore/Persistence/`.
- Implement schema v1 with `DatabaseMigrator`, WAL mode for file-backed SQLite, external-content FTS5 table, and seed insertion when the item table is empty.
- Persist and round-trip items, highlights, tags, folders, feeds, item-tag links, summary JSON, and content body JSON.
- Implement FTS search over title, excerpt, and body text, returning item IDs.
- Keep `SampleLibrary` for previews/tests and use it as the initial seed source.
- Apply section 5 model fixes included in Task A: generate new item IDs with `UUID().uuidString`, and replace `ReaderItem.time`/`timestamp` with `publishedAt: Date` plus derived relative display text.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- Tests cover empty database migration.
- Tests cover item/highlight/tag round-trip.
- Tests cover FTS search for English and Chinese text.
- Tests cover cascade deletion of related highlights and item-tag rows.
- UI and ReaderStore layers do not import GRDB.

## Out of Scope

- ReaderStore repository injection and startup `loadLibrary`.
- Persisting favorite/read/highlight/new-item/reading-position writes from ReaderStore.
- Reading-position persistence and throttling.
- Moving typography/theme/preferences to UserDefaults.
- Killing and reopening the app to prove end-to-end persistence.
- iCloud/sync, pagination, ValueObservation, custom FTS tokenizers, live RSS/URL ingestion, AI services, and chat persistence.

## Technical Notes

- The current codebase is a single SwiftPM package with `ReaderCore`, `ReaderMacApp`, and `ReaderCoreTests`.
- `ReaderItem` currently uses `time: String` and `timestamp: Int`; sorting and UI display must switch to `publishedAt: Date`.
- `ReaderStore.addItem` currently uses `"u\(items.count + 1)"`, which must be replaced by UUID generation.
- Existing tests include an explicit memory-only reading offset test; Task A should not change the reading offset behavior yet because section 8 assigns that wiring to Task B.
