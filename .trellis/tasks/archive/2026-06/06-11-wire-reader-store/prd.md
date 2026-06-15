# 接线 ReaderStore

## Goal

Implement Task B from `.trellis/spec/guides/persistence-design.md` section 8: connect `ReaderStore` to the local `ReaderRepository` foundation so user-facing library state survives app restart.

## Binding Design

- `.trellis/spec/guides/persistence-design.md` is authoritative for this task.
- Task B continues from Task A commit `d0c14ea`.
- Follow section 2 data flow: write operations update in-memory `@Published` state first, then persist asynchronously through `ReaderRepository`.
- `ReaderStore` and SwiftUI views must not import GRDB.

## Requirements

- Inject `ReaderRepository` into `ReaderStore`.
- On startup, load `LibrarySnapshot` from the repository and publish items/tags/folders/feeds.
- Persist user-facing mutations through the repository:
  - selecting an item marks it read;
  - favorite/unfavorite;
  - mark all read;
  - add item;
  - add/update highlights and notes;
  - reading progress and reading offset.
- Persist reading state through `saveReadingState`; do not write on every scroll event. Use throttling/debounce or a bounded deferred write strategy.
- Move typography/theme/reading preferences from process-only state to `UserDefaults` / `@AppStorage`-compatible storage. These preferences must not go into SQLite.
- Connect list search to repository FTS, or keep memory search as a deliberate fallback and document the decision.
- Preserve preview/test ergonomics through `InMemoryRepository`.

## Acceptance Criteria

- `swift build` passes.
- `swift test` passes.
- `./script/build_and_run.sh --verify` passes.
- Kill and reopen the app after adding content, adding a highlight/note, toggling favorite/read state, and changing reading position; those states are still present.
- ReaderStore/View layers have no `import GRDB`.

## Out of Scope

- iCloud or multi-device sync.
- URL/RSS real fetching.
- AI service integration.
- Chat history persistence.
- Pagination or `ValueObservation` reactive synchronization.
- Custom FTS tokenizer.

## Technical Notes

- Task A added `LibrarySnapshot`, `ReaderRepository`, `GRDBRepository`, `InMemoryRepository`, and schema v1.
- Current `ReaderStore` still defaults to `SampleLibrary` and keeps reading offsets/preferences in memory.
- Existing test `testReadingOffsetIsMemoryOnlyAndNonNegative` must be updated because section 5.3 requires reading position persistence in Task B.
- Trellis/agent/bootstrap files are local workflow files and should not be included in business commits.
