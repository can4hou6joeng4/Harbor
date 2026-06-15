@testable import ReaderCore
import XCTest

final class FeedSyncTests: XCTestCase {
    func testAddFeedParsesTitleAndSavesSubscription() async throws {
        let feedURL = URL(string: "https://feeds.example.com/rss.xml")!
        let repository = InMemoryRepository(snapshot: .empty)
        let httpClient = FeedFixtureHTTPClient(responses: [
            feedURL.absoluteString: CaptureResponse(
                url: feedURL,
                mimeType: "application/rss+xml",
                headers: ["etag": "\"rss-etag\"", "last-modified": "Mon, 01 Jun 2026 10:30:00 GMT"],
                data: try fixtureData("sample-rss", fileExtension: "xml")
            )
        ])
        let service = FeedSyncService(repository: repository, httpClient: httpClient)

        let feed = try await service.addFeed(urlString: feedURL.absoluteString)
        let snapshot = try await repository.loadLibrary()

        XCTAssertEqual(feed.name, "Example RSS")
        XCTAssertEqual(feed.url, feedURL.absoluteString)
        XCTAssertNil(feed.etag)
        XCTAssertNil(feed.lastModified)
        XCTAssertEqual(snapshot.platforms.first?.feeds.first?.name, "Example RSS")
        XCTAssertNil(snapshot.platforms.first?.feeds.first?.etag)
        XCTAssertNil(snapshot.platforms.first?.feeds.first?.lastModified)
    }

    func testRSSSyncInsertsItemsAndSkipsDuplicates() async throws {
        let feedURL = URL(string: "https://feeds.example.com/rss.xml")!
        let feed = makeFeed(id: "f-rss", name: "Example RSS", url: feedURL.absoluteString)
        let repository = InMemoryRepository(snapshot: .empty)
        try await repository.saveFeed(feed, platformID: "p-rss")
        let service = FeedSyncService(
            repository: repository,
            httpClient: FeedFixtureHTTPClient(responses: [
                feedURL.absoluteString: CaptureResponse(
                    url: feedURL,
                    mimeType: "application/rss+xml",
                    headers: ["etag": "\"rss-etag\""],
                    data: try fixtureData("sample-rss", fileExtension: "xml")
                )
            ])
        )

        let first = await service.sync(feed: feed)
        let second = await service.sync(feed: feed)
        let snapshot = try await repository.loadLibrary()

        XCTAssertNil(first.errorMessage)
        XCTAssertEqual(first.insertedCount, 2)
        XCTAssertEqual(second.insertedCount, 0)
        XCTAssertEqual(second.skippedCount, 2)
        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertEqual(Set(snapshot.items.compactMap(\.guid)), Set(["rss-guid-1", "https://feeds.example.com/second"]))
        XCTAssertTrue(snapshot.items.contains { $0.isSummaryOnly && $0.title == "Second RSS Article" })
    }

    func testAtomSyncCoversGuidFallbackChain() async throws {
        let feedURL = URL(string: "https://atom.example.com/feed.xml")!
        let feed = makeFeed(id: "f-atom", name: "Example Atom", url: feedURL.absoluteString)
        let repository = InMemoryRepository(snapshot: .empty)
        try await repository.saveFeed(feed, platformID: "p-rss")
        let service = FeedSyncService(
            repository: repository,
            httpClient: FeedFixtureHTTPClient(responses: [
                feedURL.absoluteString: CaptureResponse(
                    url: feedURL,
                    mimeType: "application/atom+xml",
                    data: try fixtureData("sample-atom", fileExtension: "xml")
                )
            ])
        )

        let result = await service.sync(feed: feed)
        let snapshot = try await repository.loadLibrary()

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.insertedCount, 3)
        XCTAssertTrue(snapshot.items.contains { $0.guid == "atom-id-1" })
        XCTAssertTrue(snapshot.items.contains { $0.guid == "https://atom.example.com/link-identity" })
        let hashed = try XCTUnwrap(snapshot.items.first { $0.title == "Atom Entry With Hashed Identity" })
        XCTAssertFalse(hashed.guid?.isEmpty ?? true)
        XCTAssertNil(hashed.url)
    }

    func testNotModifiedUpdatesFetchedAtAndSendsConditionalHeaders() async throws {
        let feedURL = URL(string: "https://feeds.example.com/rss.xml")!
        let feed = makeFeed(
            id: "f-rss",
            name: "Example RSS",
            url: feedURL.absoluteString,
            etag: "\"old-etag\"",
            lastModified: "Mon, 01 Jun 2026 10:30:00 GMT"
        )
        let repository = InMemoryRepository(snapshot: .empty)
        try await repository.saveFeed(feed, platformID: "p-rss")
        let httpClient = FeedFixtureHTTPClient(responses: [
            feedURL.absoluteString: CaptureResponse(
                url: feedURL,
                statusCode: 304,
                mimeType: "application/rss+xml",
                data: Data()
            )
        ])
        let service = FeedSyncService(repository: repository, httpClient: httpClient)

        let result = await service.sync(feed: feed)
        let snapshot = try await repository.loadLibrary()
        let savedFeed = try XCTUnwrap(snapshot.platforms.first?.feeds.first)
        let requests = await httpClient.recordedRequests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertTrue(result.notModified)
        XCTAssertEqual(result.insertedCount, 0)
        XCTAssertEqual(savedFeed.etag, "\"old-etag\"")
        XCTAssertNotNil(savedFeed.lastFetchedAt)
        XCTAssertEqual(request.headers["If-None-Match"], "\"old-etag\"")
        XCTAssertEqual(request.headers["If-Modified-Since"], "Mon, 01 Jun 2026 10:30:00 GMT")
    }

    func testSyncAllIsolatesSingleFeedFailure() async throws {
        let goodURL = URL(string: "https://feeds.example.com/rss.xml")!
        let badURL = URL(string: "https://feeds.example.com/missing.xml")!
        let goodFeed = makeFeed(id: "f-good", name: "Good", url: goodURL.absoluteString)
        let badFeed = makeFeed(id: "f-bad", name: "Bad", url: badURL.absoluteString)
        let repository = InMemoryRepository(snapshot: .empty)
        try await repository.saveFeed(goodFeed, platformID: "p-rss")
        try await repository.saveFeed(badFeed, platformID: "p-rss")
        let service = FeedSyncService(
            repository: repository,
            httpClient: FeedFixtureHTTPClient(responses: [
                goodURL.absoluteString: CaptureResponse(
                    url: goodURL,
                    mimeType: "application/rss+xml",
                    data: try fixtureData("sample-rss", fileExtension: "xml")
                )
            ])
        )

        let summary = await service.syncAll(feeds: [goodFeed, badFeed])
        let snapshot = try await repository.loadLibrary()

        XCTAssertEqual(summary.insertedCount, 2)
        XCTAssertEqual(summary.failureCount, 1)
        XCTAssertEqual(snapshot.items.count, 2)
    }

    private func makeFeed(
        id: String,
        name: String,
        url: String,
        etag: String? = nil,
        lastModified: String? = nil
    ) -> Feed {
        Feed(
            id: id,
            name: name,
            monogram: String(name.prefix(1)),
            colorHex: "#E0533D",
            count: 0,
            url: url,
            etag: etag,
            lastModified: lastModified
        )
    }

    private func fixtureData(_ name: String, fileExtension: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: fileExtension))
        return try Data(contentsOf: url)
    }
}

private actor FeedFixtureHTTPClient: HTTPClient {
    private var responses: [String: CaptureResponse]
    private var requests: [CaptureRequest] = []

    init(responses: [String: CaptureResponse]) {
        self.responses = responses
    }

    func fetch(_ request: CaptureRequest) async throws -> CaptureResponse {
        requests.append(request)
        guard let response = responses[request.url.absoluteString] else {
            throw HTTPClientError.badStatus(404)
        }
        return response
    }

    func recordedRequests() -> [CaptureRequest] {
        requests
    }
}
