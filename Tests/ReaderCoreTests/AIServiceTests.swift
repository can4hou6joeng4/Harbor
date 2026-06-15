@testable import ReaderCore
import XCTest

final class AIServiceTests: XCTestCase {
    func testSSEParserAccumulatesTextDeltas() throws {
        var parser = AnthropicSSEParser()
        var output: [String] = []

        output += try parser.consume("event: content_block_delta")
        output += try parser.consume(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello "}}"#)
        output += try parser.consume("")
        output += try parser.consume("event: content_block_delta")
        output += try parser.consume(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"world"}}"#)
        output += try parser.consume("")
        output += try parser.finish()

        XCTAssertEqual(output.joined(), "Hello world")
    }

    func testSSEParserHandlesDataSplitAcrossLines() throws {
        var parser = AnthropicSSEParser()
        var output: [String] = []

        output += try parser.consume("event: content_block_delta")
        output += try parser.consume(#"data: {"type":"content_block_delta","#)
        output += try parser.consume(#"data: "delta":{"type":"text_delta","text":"跨行"}}"#)
        output += try parser.consume("")

        XCTAssertEqual(output, ["跨行"])
    }

    func testStructuredSummaryDecode() throws {
        let expected = ReaderSummary(
            text: ["这是一段摘要。"],
            keys: ["要点一", "要点二", "要点三"],
            tagSuggestions: ["本地优先", "AI"]
        )

        let decoded = try AnthropicService.decodeSummary(from: try anthropicSummaryResponse(expected))

        XCTAssertEqual(decoded, expected)
    }

    func testRateLimitRetryAfterIsRetried() async throws {
        let expected = ReaderSummary(
            text: ["已重试后返回。"],
            keys: ["重试", "限流", "成功"],
            tagSuggestions: ["AI", "测试"]
        )
        let client = MockAIClient(responses: [
            .success(AIHTTPResponse(statusCode: 429, headers: ["retry-after": "2"], data: Data())),
            .success(AIHTTPResponse(statusCode: 200, data: try anthropicSummaryResponse(expected)))
        ])
        let keyStore = MemoryKeyStore(key: "test-api-key")
        let settings = makeEnabledSettings()
        let delays = DelayRecorder()
        let service = AnthropicService(
            client: client,
            keyStore: keyStore,
            settings: settings,
            maxRetries: 1,
            sleeper: { delay in delays.append(delay) }
        )

        let summary = try await service.summarize(makeItem())

        XCTAssertEqual(summary, expected)
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(delays.values, [2])
    }

    func testInvalidKeyIsNotRetried() async throws {
        let client = MockAIClient(responses: [
            .success(AIHTTPResponse(statusCode: 401, data: Data()))
        ])
        let service = AnthropicService(
            client: client,
            keyStore: MemoryKeyStore(key: "test-api-key"),
            settings: makeEnabledSettings(),
            maxRetries: 3,
            sleeper: { _ in }
        )

        do {
            _ = try await service.summarize(makeItem())
            XCTFail("Expected invalid key error")
        } catch let error as AIError {
            XCTAssertEqual(error, .invalidAPIKey)
        }

        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testCancellationMapsToAIError() async throws {
        let client = MockAIClient(responses: [
            .failure(CancellationError())
        ])
        let service = AnthropicService(
            client: client,
            keyStore: MemoryKeyStore(key: "test-api-key"),
            settings: makeEnabledSettings(),
            sleeper: { _ in }
        )

        do {
            _ = try await service.summarize(makeItem())
            XCTFail("Expected cancellation")
        } catch let error as AIError {
            XCTAssertEqual(error, .cancelled)
        }
    }

    func testArticleTextIsTruncated() {
        var item = makeItem()
        item.body = [
            ContentBlock(kind: .paragraph, language: "zh", text: String(repeating: "长正文", count: 100))
        ]

        let prompt = Prompts.articleText(for: item, maxCharacters: 80)

        XCTAssertTrue(prompt.wasTruncated)
        XCTAssertTrue(prompt.text.hasSuffix("[正文已截断]"))
    }

    func testSummaryRequestHeadersAndBodyShape() async throws {
        let expected = ReaderSummary(
            text: ["摘要"],
            keys: ["一", "二", "三"],
            tagSuggestions: ["标签", "测试"]
        )
        let client = MockAIClient(responses: [
            .success(AIHTTPResponse(statusCode: 200, data: try anthropicSummaryResponse(expected)))
        ])
        let service = AnthropicService(
            client: client,
            keyStore: MemoryKeyStore(key: "test-api-key"),
            settings: makeEnabledSettings(),
            sleeper: { _ in }
        )

        _ = try await service.summarize(makeItem())
        let firstRequest = await client.firstRequest
        let request = try XCTUnwrap(firstRequest)
        let body = try XCTUnwrap(request.body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")
        XCTAssertEqual(request.headers["x-api-key"], "test-api-key")
        XCTAssertEqual(object["model"] as? String, AnthropicModel.default.rawValue)
        XCTAssertEqual(object["max_tokens"] as? Int, 1024)
    }

    func testTranslationDecodeAndRequestBodyShape() async throws {
        let item = makeItem()
        let blockID = try XCTUnwrap(item.body.first?.id.uuidString)
        let client = MockAIClient(responses: [
            .success(AIHTTPResponse(statusCode: 200, data: try anthropicTranslationResponse([blockID: "Translated body"])))
        ])
        let service = AnthropicService(
            client: client,
            keyStore: MemoryKeyStore(key: "test-api-key"),
            settings: makeEnabledSettings(),
            sleeper: { _ in }
        )

        let translations = try await service.translate(item, to: "en")
        let firstRequest = await client.firstRequest
        let request = try XCTUnwrap(firstRequest)
        let body = try XCTUnwrap(request.body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(translations[blockID], "Translated body")
        XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")
        XCTAssertEqual(request.headers["x-api-key"], "test-api-key")
        XCTAssertEqual(object["max_tokens"] as? Int, 2048)
        XCTAssertNil(object["temperature"])
        XCTAssertNil(object["top_p"])
        XCTAssertNil(object["top_k"])
        XCTAssertNil(object["budget_tokens"])
    }

    func testTranslationDecodeToleratesDuplicateBlockIDs() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "content": [
                [
                    "type": "text",
                    "text": """
                    {"translations":[{"id":"block-1","text":"first"},{"id":"block-1","text":"second"}]}
                    """
                ]
            ]
        ])

        let translations = try AnthropicService.decodeTranslations(from: data)

        XCTAssertEqual(translations["block-1"], "second")
    }

    func testChatStreamsTokensAndRequestBodyShape() async throws {
        let client = MockAIClient(
            responses: [],
            streamResponses: [
                .success(["Hello ", "reader"])
            ]
        )
        let service = AnthropicService(
            client: client,
            keyStore: MemoryKeyStore(key: "test-api-key"),
            settings: makeEnabledSettings(),
            sleeper: { _ in }
        )

        var output = ""
        for try await token in service.chat(
            messages: [ChatMessage(role: .user, text: "Explain this")],
            about: makeItem()
        ) {
            output += token
        }
        let firstStreamRequest = await client.firstStreamRequest
        let request = try XCTUnwrap(firstStreamRequest)
        let body = try XCTUnwrap(request.body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(output, "Hello reader")
        XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")
        XCTAssertEqual(request.headers["x-api-key"], "test-api-key")
        XCTAssertEqual(object["stream"] as? Bool, true)
        XCTAssertEqual(object["max_tokens"] as? Int, 4096)
        XCTAssertNil(object["temperature"])
        XCTAssertNil(object["top_p"])
        XCTAssertNil(object["top_k"])
        XCTAssertNil(object["budget_tokens"])
    }

    func testRemixStreamRetriesBeforeFirstToken() async throws {
        let delays = DelayRecorder()
        let client = MockAIClient(
            responses: [],
            streamResponses: [
                .failure(AIError.rateLimited(retryAfter: 1)),
                .success(["# Draft"])
            ]
        )
        let service = AnthropicService(
            client: client,
            keyStore: MemoryKeyStore(key: "test-api-key"),
            settings: makeEnabledSettings(),
            maxRetries: 1,
            sleeper: { delay in delays.append(delay) }
        )

        var output = ""
        for try await token in service.remix(type: "rx-note", items: [makeItem()]) {
            output += token
        }

        XCTAssertEqual(output, "# Draft")
        let streamRequestCount = await client.streamRequestCount
        XCTAssertEqual(streamRequestCount, 2)
        XCTAssertEqual(delays.values, [1])
    }

    func testKeychainRoundTripAndUnconfiguredState() throws {
        let store = APIKeyStore(service: "ReaderMacAppTests.\(UUID().uuidString)", account: "anthropic")
        defer { try? store.deleteAPIKey() }

        XCTAssertFalse(store.hasAPIKey)

        try store.saveAPIKey("roundtrip-key-1234")

        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(try store.loadAPIKey(), "roundtrip-key-1234")
        XCTAssertEqual(try store.maskedAPIKey(), "••••1234")

        try store.deleteAPIKey()
        XCTAssertFalse(store.hasAPIKey)
    }

    private func makeEnabledSettings() -> AISettings {
        let suiteName = "AIServiceTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let settings = AISettings(userDefaults: userDefaults)
        settings.isEnabled = true
        return settings
    }

    private func anthropicSummaryResponse(_ summary: ReaderSummary) throws -> Data {
        let summaryData = try JSONEncoder().encode(summary)
        let summaryText = String(data: summaryData, encoding: .utf8)!
        return try JSONSerialization.data(withJSONObject: [
            "content": [
                [
                    "type": "text",
                    "text": summaryText
                ]
            ]
        ])
    }

    private func anthropicTranslationResponse(_ translations: [String: String]) throws -> Data {
        let payload = [
            "translations": translations.map { ["id": $0.key, "text": $0.value] }
        ]
        let translationData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let translationText = String(data: translationData, encoding: .utf8)!
        return try JSONSerialization.data(withJSONObject: [
            "content": [
                [
                    "type": "text",
                    "text": translationText
                ]
            ]
        ])
    }

    private func makeItem() -> ReaderItem {
        ReaderItem(
            id: "ai-test-item",
            type: "article",
            kind: .web,
            source: "Tests",
            author: "Tester",
            title: "AI Test",
            excerpt: "Excerpt",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            readingTime: 1,
            language: "zh",
            tagIDs: [],
            folderID: "",
            isFavorite: false,
            isUnread: true,
            progress: 0,
            hue: 120,
            hasCover: false,
            body: [ContentBlock(kind: .paragraph, language: "zh", text: "正文")],
            summary: ReaderSummary(text: [], keys: [], tagSuggestions: [])
        )
    }
}

private actor MockAIClient: AIClient {
    private(set) var requests: [AIHTTPRequest] = []
    private(set) var streamRequests: [AIHTTPRequest] = []
    private var responses: [Result<AIHTTPResponse, Error>]
    private var streamResponses: [Result<[String], Error>]

    init(responses: [Result<AIHTTPResponse, Error>], streamResponses: [Result<[String], Error>] = []) {
        self.responses = responses
        self.streamResponses = streamResponses
    }

    var requestCount: Int {
        requests.count
    }

    var streamRequestCount: Int {
        streamRequests.count
    }

    var firstRequest: AIHTTPRequest? {
        requests.first
    }

    var firstStreamRequest: AIHTTPRequest? {
        streamRequests.first
    }

    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw AIError.invalidResponse
        }
        return try responses.removeFirst().get()
    }

    nonisolated func stream(_ request: AIHTTPRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let response = await nextStreamResponse(for: request)
                do {
                    for token in try response.get() {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func nextStreamResponse(for request: AIHTTPRequest) -> Result<[String], Error> {
        streamRequests.append(request)
        return streamResponses.isEmpty ? .success([]) : streamResponses.removeFirst()
    }
}

private final class MemoryKeyStore: APIKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    init(key: String?) {
        self.key = key
    }

    var hasAPIKey: Bool {
        lock.lock()
        defer { lock.unlock() }
        return key?.isEmpty == false
    }

    func loadAPIKey() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return key
    }

    func saveAPIKey(_ key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        self.key = key
    }

    func deleteAPIKey() throws {
        lock.lock()
        defer { lock.unlock() }
        key = nil
    }

    func maskedAPIKey() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let key else { return nil }
        return "••••\(key.suffix(4))"
    }
}

private final class DelayRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [TimeInterval] = []

    var values: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }
}
