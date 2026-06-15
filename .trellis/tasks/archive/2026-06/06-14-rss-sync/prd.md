# RSS 同步

## Goal

Implement Task D from `.trellis/spec/guides/content-capture-design.md`: RSS/Atom subscriptions become real, can be added from the subscriptions UI, synchronize into local Reader items, survive restart, and avoid duplicates.

## Requirements

* Add FeedKit to `ReaderCore`; keep FeedKit out of the UI target.
* Add `FeedSyncService` under `ReaderCore/Capture/`, using the existing `HTTPClient` as the only network boundary and `ReaderRepository` as the persistence boundary.
* Parse RSS, Atom, and JSON Feed through `FeedParser(data:)`; do not use FeedKit URL/network APIs.
* Implement entry identity fallback: `guid/id -> link -> hash(title + pubDate)`.
* Use v2 feed metadata for conditional requests: `If-None-Match` and `If-Modified-Since`; 304 updates `last_fetched_at` and skips parsing.
* Skip duplicate feed entries using the v2 unique index semantics; do not update existing items.
* Sync enabled feeds with failure isolation: one feed failure must not abort other feeds.
* Limit feed sync concurrency to 4.
* Map feed entry body through the same SwiftSoup cleaning/block mapping used by URL capture; short bodies become summary-type RSS items, not failed syncs.
* Add a “fetch full article” path for summary-type RSS entries by preserving `url` and letting the UI expose a bottom action placeholder if needed.
* Wire subscriptions UI so a real RSS URL can be added and synchronized. X/Weibo/YouTube remain seeded only and out of scope.
* Add app-start/hourly/manual refresh strategy at the Store level with lightweight UI progress.

## Acceptance Criteria

* [x] Adding `https://www.ruanyifeng.com/blog/atom.xml` can sync items, save them locally, and reload them after restart.
* [x] Re-syncing the same feed does not create duplicates.
* [x] Fixture tests cover RSS/Atom parsing, guid fallback chain, 304 path, and single-feed failure isolation.
* [x] Test code performs no real network I/O; all feed data goes through mock `HTTPClient` + fixtures.
* [x] `swift build`, `swift test`, and `./script/build_and_run.sh --verify` pass or any non-pass is documented with the exact blocker.

## Definition of Done

* `FeedSyncService` depends on `ReaderRepository`, `HTTPClient`, and parser/extractor abstractions, not GRDB.
* Repository protocols expose only the feed/subscription operations needed by sync and UI.
* UI target does not import FeedKit or SwiftSoup.
* Sync failures are visible in subscription management without modal/toast spam for every feed.
* The implementation preserves the documented out-of-scope boundary: no X, Weibo, YouTube real sync; no attachment import; no JS-rendered full article fallback.

## Technical Approach

Follow `.trellis/spec/guides/content-capture-design.md` sections 6, 9, and 11 directly. The cross-layer flow is:

`SubscriptionsModal/manual refresh/app timer -> ReaderStore -> FeedSyncService -> HTTPClient -> FeedKit parser -> SwiftSoupExtractor/block mapping -> ReaderRepository -> ReaderStore snapshot`.

Feed bodies use `content:encoded` before `description`. Full text recovery for summary feeds is represented by preserving `url` and an explicit summary flag in item metadata/body behavior; Task C’s capture pipeline remains the future full-article path.

## Decision (ADR-lite)

**Context**: The binding design guide already chooses FeedKit and requires network isolation through `HTTPClient`.

**Decision**: Implement RSS sync as a ReaderCore service behind `ReaderStore`, using fixture-backed tests for every network/parser path.

**Consequences**: Sync can be tested deterministically and later extended to OPML or richer feed management without pushing parser/network code into SwiftUI.

## Out of Scope

* X, Weibo, and YouTube real subscription sync.
* OPML import/export.
* Push notifications.
* Attachment/PDF/image/video import; that is Task E.
* Updating existing duplicate items during sync.

## Technical Notes

* Binding design: `.trellis/spec/guides/content-capture-design.md`.
* Feed metadata persistence was added in Task C schema v2.
* Existing subscription UI path: `Sources/ReaderMacApp/Views/OverlaysView.swift`.
* Existing platform/feed display path: `ReaderStore.platforms`, `SidebarView`, and `SubscriptionsModal`.
* Existing capture HTTP/extraction utilities from Task C should be reused rather than duplicated.
