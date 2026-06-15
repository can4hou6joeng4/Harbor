# Implementation Notes

## Verification

* `swift build` passed in final closeout.
* `swift test` passed in final closeout with 39 tests.
* `./script/build_and_run.sh --verify` passed in final closeout.
* Boundary check: UI and `ReaderStore` do not import FeedKit, SwiftSoup, or GRDB.
* Test network check: tests use mock `HTTPClient`; no test source references `URLSession`.

## Manual Verification

* Real feed smoke used `https://www.ruanyifeng.com/blog/atom.xml`; direct HTTP returned 200 with XML content.
* The first real run exposed a fixture gap: `FeedSyncService.addFeed` stored `etag`/`lastModified` before initial item sync, so an immediate first sync sent conditional headers and received 304, inserting 0 items.
* Fixed by leaving new-feed `etag` and `lastModified` nil until an actual sync succeeds; added a regression assertion in `FeedSyncTests`.
* After the fix, real sync inserted 3 阮一峰 entries with no failures.
* Reopening the app showed the 阮一峰 feed and synced entries still present.
* A second sync inserted 0 new items and the stored entry count stayed 3 with 3 distinct GUIDs, confirming no duplicates.
