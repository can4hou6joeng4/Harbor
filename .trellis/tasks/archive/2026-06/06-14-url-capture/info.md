# Implementation Notes

## Verification

* `swift build` passed in final closeout.
* `swift test` passed in final closeout with 39 tests.
* `./script/build_and_run.sh --verify` passed in final closeout.
* Boundary check: `Sources/ReaderMacApp` and `ReaderStore` do not import SwiftSoup, FeedKit, or GRDB.
* Test network check: test sources contain fixture/mock URL strings but no `URLSession` usage.
* Migration check: v1 migration block is unchanged; v2 is appended after v1.

## Manual Verification

* Real URL smoke passed with `https://www.apple.com/newsroom/2024/06/introducing-apple-intelligence-for-iphone-ipad-and-mac/`.
* App preview showed the real title, source domain, excerpt, and downloaded cover image.
* Saving created a persisted local item; after killing and reopening the app, the Apple item and cover thumbnail were still visible.
* Database check confirmed the saved item had a non-null `cover_path` and full `body_json` content.
* Failure-path smoke passed through `URLSessionHTTPClient -> CaptureService -> SwiftSoupExtractor` against a local HTTP server:
  * Non-HTML response (`application/pdf`) returned `链接不是可提取的 HTML 页面`.
  * Short HTML body returned `未能提取正文`.
  * Slow response with a 1s client timeout returned `请求超时`.
* RSS summary-only follow-up checked: `ReaderDetailView` already shows `抓取全文` for `item.isSummaryOnly && item.url != nil`, and `ReaderStore.fetchFullArticle(for:)` calls Task C's capture pipeline, replaces body/metadata, removes `summaryOnlyMarker`, persists, and shows `已抓取全文`.
