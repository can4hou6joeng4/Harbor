@testable import ReaderCore
import XCTest

final class CaptureTests: XCTestCase {
    func testExtractorHandlesChineseBlogFixture() throws {
        let extracted = try extractFixture(
            "chinese-blog",
            sourceURL: URL(string: "https://www.ruanyifeng.com/blog/2026/06/local-reader.html")!
        )

        XCTAssertEqual(extracted.title, "本地优先阅读器的内容采集实践 - 阮一峰的网络日志")
        XCTAssertEqual(extracted.author, "阮一峰")
        XCTAssertTrue(extracted.excerpt.contains("本地优先阅读器"))
        XCTAssertTrue(extracted.blocks.contains { $0.kind == .heading && $0.text == "内容采集为什么重要" })
        XCTAssertTrue(extracted.blocks.contains { $0.kind == .quote })
        XCTAssertFalse(extracted.text.contains("广告位"))
    }

    func testExtractorHandlesEnglishLongformFixture() throws {
        let extracted = try extractFixture(
            "english-longform",
            sourceURL: URL(string: "https://example.com/longform")!
        )

        XCTAssertEqual(extracted.title, "The Durable Web Reader")
        XCTAssertEqual(extracted.author, "A. Writer")
        let expectedDate = ISO8601DateFormatter().date(from: "2026-06-01T10:30:00Z")
        XCTAssertEqual(extracted.publishedAt.timeIntervalSince1970, expectedDate?.timeIntervalSince1970 ?? 0, accuracy: 0.001)
        XCTAssertTrue(extracted.blocks.contains { $0.kind == .lead && $0.text.contains("durable reader starts") })
        XCTAssertTrue(extracted.blocks.contains { $0.kind == .heading && $0.text == "Prefer predictable fallbacks" })
        XCTAssertFalse(extracted.text.contains("Subscribe now"))
    }

    func testExtractorHandlesNewsFixtureWithCoverAndBodyImage() throws {
        let sourceURL = URL(string: "https://news.example.com/archive/story")!
        let extracted = try extractFixture("news-with-cover", sourceURL: sourceURL)

        XCTAssertEqual(extracted.title, "Local Archives Reach Mainstream Newsrooms")
        XCTAssertEqual(extracted.coverImageURL?.absoluteString, "https://news.example.com/images/local-archive-cover.png")
        let imageBlock = try XCTUnwrap(extracted.blocks.first { $0.kind == .image })
        XCTAssertEqual(imageBlock.text, "https://news.example.com/images/chart.png")
        XCTAssertEqual(imageBlock.caption, "Archive growth across local-first reading tools.")
        XCTAssertFalse(extracted.text.contains("Reader comments"))
    }

    func testCaptureServicePreviewsSavesAndStoresCoverWithMockHTTP() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let articleURL = URL(string: "https://news.example.com/archive/story")!
        let coverURL = URL(string: "https://news.example.com/images/local-archive-cover.png")!
        let repository = InMemoryRepository(snapshot: .empty)
        let service = CaptureService(
            repository: repository,
            httpClient: FixtureHTTPClient(responses: [
                articleURL.absoluteString: CaptureResponse(
                    url: articleURL,
                    mimeType: "text/html",
                    textEncodingName: "utf-8",
                    data: try fixtureData("news-with-cover")
                ),
                coverURL.absoluteString: CaptureResponse(
                    url: coverURL,
                    mimeType: "image/png",
                    data: Data([0x89, 0x50, 0x4E, 0x47])
                )
            ]),
            assetStore: LocalCaptureAssetStore(rootDirectory: rootDirectory)
        )

        let preview = try await service.preview(urlString: articleURL.absoluteString)

        XCTAssertEqual(preview.title, "Local Archives Reach Mainstream Newsrooms")
        XCTAssertEqual(preview.source, "news.example.com")
        XCTAssertEqual(preview.language, "en")
        XCTAssertTrue(preview.readingTime >= 1)
        let coverPath = try XCTUnwrap(preview.coverPath)
        XCTAssertTrue(coverPath.hasPrefix("Attachments/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent(coverPath).path))

        let item = try await service.save(preview, tagIDs: ["t-test"], folderID: "fo-test")
        let snapshot = try await repository.loadLibrary()
        let saved = try XCTUnwrap(snapshot.items.first)
        XCTAssertEqual(saved.id, item.id)
        XCTAssertEqual(saved.url, articleURL.absoluteString)
        XCTAssertEqual(saved.coverPath, coverPath)
        XCTAssertEqual(saved.tagIDs, ["t-test"])
        XCTAssertEqual(saved.folderID, "fo-test")
        XCTAssertFalse(saved.body.isEmpty)
    }

    func testCaptureServiceDoesNotSaveShortExtraction() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let articleURL = URL(string: "https://example.com/short")!
        let repository = InMemoryRepository(snapshot: .empty)
        let service = CaptureService(
            repository: repository,
            httpClient: FixtureHTTPClient(responses: [
                articleURL.absoluteString: CaptureResponse(
                    url: articleURL,
                    mimeType: "text/html",
                    textEncodingName: "utf-8",
                    data: Data("<html><body><article><p>Too short.</p></article></body></html>".utf8)
                )
            ]),
            assetStore: LocalCaptureAssetStore(rootDirectory: rootDirectory)
        )

        do {
            _ = try await service.preview(urlString: articleURL.absoluteString)
            XCTFail("Expected extraction failure")
        } catch let error as CaptureError {
            XCTAssertEqual(error.localizedDescription, "未能提取正文")
        }

        let snapshot = try await repository.loadLibrary()
        XCTAssertTrue(snapshot.items.isEmpty)
    }

    func testHTTPTimeoutHasLocalizedDescription() {
        XCTAssertEqual(HTTPClientError.timeout.localizedDescription, "请求超时")
    }

    private func extractFixture(_ name: String, sourceURL: URL) throws -> ExtractedContent {
        try SwiftSoupExtractor().extract(html: fixtureString(name), sourceURL: sourceURL)
    }

    private func fixtureString(_ name: String) throws -> String {
        String(data: try fixtureData(name), encoding: .utf8)!
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try Data(contentsOf: url)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderMacAppCaptureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private struct FixtureHTTPClient: HTTPClient {
    var responses: [String: CaptureResponse]

    func fetch(_ request: CaptureRequest) async throws -> CaptureResponse {
        guard let response = responses[request.url.absoluteString] else {
            throw HTTPClientError.badStatus(404)
        }
        return response
    }
}
