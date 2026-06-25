@testable import ReaderCore
import XCTest

final class OPMLImporterTests: XCTestCase {
    func testParsesNestedCategoriesAndFeeds() throws {
        let feeds = try OPMLImporter().parse(fixtureData("subscriptions", fileExtension: "opml"))

        XCTAssertEqual(feeds.count, 3)
        XCTAssertEqual(feeds[0].title, "Example RSS")
        XCTAssertEqual(feeds[0].xmlURL, "https://feeds.example.com/rss.xml")
        XCTAssertEqual(feeds[0].category, "Tech")
        XCTAssertEqual(feeds[1].title, "Second Feed")          // falls back to text attribute
        XCTAssertEqual(feeds[1].category, "Tech")
        XCTAssertEqual(feeds[2].title, "Top Level Feed")
        XCTAssertNil(feeds[2].category)                         // category stack popped after </outline>
    }

    func testTitleFallsBackToURLWhenMissing() throws {
        let feeds = try OPMLImporter().parse(string: """
        <opml><body><outline type="rss" xmlUrl="https://only-url.example/feed"/></body></opml>
        """)

        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds[0].title, "https://only-url.example/feed")
    }

    func testIgnoresNonFeedOutlinesAndRejectsBadInput() throws {
        let feeds = try OPMLImporter().parse(string: "<opml><body><outline text=\"Folder\"/></body></opml>")
        XCTAssertTrue(feeds.isEmpty)
        XCTAssertThrowsError(try OPMLImporter().parse(Data()))
        XCTAssertThrowsError(try OPMLImporter().parse(string: "<opml><body><outline"))
    }

    func testImportOPMLSkipsDuplicatesAndSyncsNewFeeds() async throws {
        let rssData = try fixtureData("sample-rss", fileExtension: "xml")
        let repository = InMemoryRepository(snapshot: .empty)
        let httpClient = OPMLStubHTTPClient(responses: [
            "https://feeds.example.com/rss.xml": CaptureResponse(
                url: URL(string: "https://feeds.example.com/rss.xml")!,
                mimeType: "application/rss+xml", headers: [:], data: rssData
            ),
            "https://feeds.example.com/second.xml": CaptureResponse(
                url: URL(string: "https://feeds.example.com/second.xml")!,
                mimeType: "application/rss+xml", headers: [:], data: rssData
            ),
        ])
        let service = FeedSyncService(repository: repository, httpClient: httpClient)

        // Pretend the top-level feed is already subscribed → it must be skipped.
        let existingID = FeedSyncService.feedID(for: URL(string: "https://news.example.org/feed")!)

        let summary = try await service.importOPML(
            fixtureData("subscriptions", fileExtension: "opml"),
            existingFeedIDs: [existingID]
        )
        let snapshot = try await repository.loadLibrary()

        XCTAssertEqual(summary.total, 3)
        XCTAssertEqual(summary.added, 2)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertGreaterThan(summary.insertedItems, 0)
        XCTAssertEqual(snapshot.platforms.first(where: { $0.id == "p-rss" })?.feeds.count, 2)
    }

    func testFeedIDIsStableForSameURL() {
        let url = URL(string: "https://feeds.example.com/rss.xml")!
        XCTAssertEqual(FeedSyncService.feedID(for: url), FeedSyncService.feedID(for: url))
        XCTAssertTrue(FeedSyncService.feedID(for: url).hasPrefix("f-"))
    }

    private func fixtureData(_ name: String, fileExtension: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: fileExtension))
        return try Data(contentsOf: url)
    }
}

private struct OPMLStubHTTPClient: HTTPClient {
    let responses: [String: CaptureResponse]

    func fetch(_ request: CaptureRequest) async throws -> CaptureResponse {
        guard let response = responses[request.url.absoluteString] else {
            throw URLError(.fileDoesNotExist)
        }
        return response
    }
}
