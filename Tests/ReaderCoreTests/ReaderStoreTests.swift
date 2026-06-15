import XCTest
@testable import ReaderCore

@MainActor
final class ReaderStoreTests: XCTestCase {
    func testUnreadViewOnlyShowsUnreadItems() {
        let store = ReaderStore()

        store.selectView("unread")

        XCTAssertFalse(store.visibleItems.isEmpty)
        XCTAssertTrue(store.visibleItems.allSatisfy(\.isUnread))
    }

    func testSelectingItemMarksItRead() {
        let store = ReaderStore()
        let unread = store.items.first { $0.isUnread }
        XCTAssertNotNil(unread)

        store.selectItem(unread!.id)

        XCTAssertFalse(store.items.first { $0.id == unread!.id }!.isUnread)
    }

    func testSearchMatchesTagNames() {
        let store = ReaderStore()
        store.selectView("all")
        store.query = "深度长文"

        XCTAssertTrue(store.visibleItems.contains { $0.id == "a1" })
    }

    func testSearchUsesRepositoryResultsForBodyMatches() async {
        var item = makeStoreItem(id: "body-search", title: "No keyword here")
        item.body = [ContentBlock(kind: .paragraph, language: "zh", text: "正文里才有跨库检索词")]
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(repository: repository, items: [item], selectedItemID: item.id)
        store.selectView("all")

        store.query = "跨库检索词"
        await store.waitForSearch()

        XCTAssertEqual(store.visibleItems.map(\.id), [item.id])
    }

    func testAddingMarkdownItemSelectsNewInboxItem() {
        let store = ReaderStore()

        store.addItem(
            from: AddContentDraft(
                mode: "md",
                title: "测试笔记",
                markdown: "正文",
                tagIDs: ["t-eff"],
                folderID: "fo-life"
            )
        )

        XCTAssertEqual(store.selectedItem?.title, "测试笔记")
        XCTAssertEqual(store.activeViewID, "inbox")
        XCTAssertEqual(store.items.first?.kind, .markdown)
    }

    func testAddingItemsUsesUniqueUUIDs() {
        let store = ReaderStore(items: [])

        store.addItem(from: AddContentDraft(mode: "md", title: "第一篇", markdown: "正文"))
        store.addItem(from: AddContentDraft(mode: "md", title: "第二篇", markdown: "正文"))

        let ids = store.items.map(\.id)
        XCTAssertEqual(Set(ids).count, 2)
        XCTAssertTrue(ids.allSatisfy { UUID(uuidString: $0) != nil })
    }

    func testSetProgressClampsToReadableRange() {
        let store = ReaderStore()

        store.setProgress("a1", progress: 1.7)
        XCTAssertEqual(store.items.first { $0.id == "a1" }?.progress, 1)

        store.setProgress("a1", progress: -0.5)
        XCTAssertEqual(store.items.first { $0.id == "a1" }?.progress, 0)
    }

    func testLoadingLibraryPublishesRepositorySnapshot() async throws {
        let item = makeStoreItem(id: "repo-item", title: "Repository item")
        let snapshot = LibrarySnapshot(
            items: [item],
            tags: [ReaderTag(id: "t-repo", name: "Repo", colorHex: "#123456")],
            folders: [ReaderFolder(id: "fo-repo", name: "Repo")],
            platforms: []
        )
        let store = ReaderStore(repository: InMemoryRepository(snapshot: snapshot), items: [], selectedItemID: nil)

        try await store.loadLibraryFromRepository()

        XCTAssertEqual(store.items.map(\.id), ["repo-item"])
        XCTAssertEqual(store.tags.map(\.id), ["t-repo"])
        XCTAssertEqual(store.folders.map(\.id), ["fo-repo"])
        XCTAssertEqual(store.selectedItemID, "repo-item")
    }

    func testSelectingItemPersistsReadFlag() async throws {
        let item = makeStoreItem(id: "persist-read", title: "Persist read", isUnread: true)
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(repository: repository, items: [item], selectedItemID: item.id)

        store.selectItem(item.id)
        await store.flushPendingPersistence()

        let saved = try await repository.loadLibrary().items.first { $0.id == item.id }
        XCTAssertEqual(saved?.isUnread, false)
    }

    func testTogglingFavoritePersistsFlag() async throws {
        let item = makeStoreItem(id: "persist-favorite", title: "Persist favorite", isFavorite: false)
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(repository: repository, items: [item], selectedItemID: item.id)

        store.toggleFavorite(item.id)
        await store.flushPendingPersistence()

        let saved = try await repository.loadLibrary().items.first { $0.id == item.id }
        XCTAssertEqual(saved?.isFavorite, true)
    }

    func testAddingMarkdownItemPersistsItem() async throws {
        let repository = InMemoryRepository(snapshot: .empty)
        let store = ReaderStore(repository: repository, items: [], selectedItemID: nil)

        store.addItem(from: AddContentDraft(mode: "md", title: "持久化笔记", markdown: "正文"))
        await store.flushPendingPersistence()

        let saved = try await repository.loadLibrary().items.first
        XCTAssertEqual(saved?.title, "持久化笔记")
        XCTAssertEqual(saved?.kind, .markdown)
    }

    func testAddingMarkdownItemDoesNotCreateFakeAISummary() {
        let store = ReaderStore(items: [])

        store.addItem(from: AddContentDraft(mode: "md", title: "无假摘要", markdown: "正文"))

        XCTAssertTrue(store.items.first?.summary.isEmpty == true)
    }

    func testRepositoryBackedStoreSurvivesReload() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("reader.sqlite")
        let repository = try GRDBRepository(databaseURL: databaseURL, seed: .sample)
        let store = ReaderStore(repository: repository, items: [], selectedItemID: nil)
        try await store.loadLibraryFromRepository()

        store.addItem(from: AddContentDraft(mode: "md", title: "重启后保留", markdown: "正文"))
        await store.flushPendingPersistence()
        let itemID = try XCTUnwrap(store.items.first { $0.title == "重启后保留" }?.id)

        store.toggleFavorite(itemID)
        store.addHighlight(itemID: itemID, quote: "正文", note: "重启验证")
        store.setReadingOffset(itemID, offset: 320)
        store.setProgress(itemID, progress: 0.7)
        await store.flushPendingPersistence()

        let reopenedRepository = try GRDBRepository(databaseURL: databaseURL, seed: nil)
        let reopenedStore = ReaderStore(repository: reopenedRepository, items: [], selectedItemID: nil)
        try await reopenedStore.loadLibraryFromRepository()

        let saved = try XCTUnwrap(reopenedStore.items.first { $0.id == itemID })
        XCTAssertEqual(saved.title, "重启后保留")
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.highlights.first?.note, "重启验证")
        XCTAssertEqual(saved.progress, 0.7, accuracy: 0.001)
        XCTAssertEqual(reopenedStore.readingOffset(for: itemID), 320)
    }

    func testReadingOffsetIsNonNegativeAndPersisted() async throws {
        let item = makeStoreItem(id: "reading-state", title: "Reading state")
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(repository: repository, items: [item], selectedItemID: item.id)

        store.setReadingOffset(item.id, offset: 420.5)
        store.setProgress(item.id, progress: 0.6)
        XCTAssertEqual(store.readingOffset(for: item.id), 420.5)

        store.setReadingOffset(item.id, offset: -80)
        await store.flushPendingPersistence()

        let saved = try await repository.loadLibrary()
        XCTAssertEqual(store.readingOffset(for: item.id), 0)
        XCTAssertEqual(store.readingOffset(for: "missing"), 0)
        XCTAssertEqual(saved.items.first?.progress, 0.6)
        XCTAssertEqual(saved.readingOffsets[item.id], 0)
    }

    func testAddHighlightReplacesExistingQuoteAndStoresNote() {
        let store = ReaderStore()

        store.addHighlight(itemID: "a1", quote: "  An agent is just a loop  ")
        store.addHighlight(itemID: "a1", quote: "An agent is just a loop", note: "循环观点")

        let highlights = store.items.first { $0.id == "a1" }?.highlights ?? []
        let matching = highlights.filter { $0.quote == "An agent is just a loop" }

        XCTAssertEqual(matching.count, 1)
        XCTAssertEqual(matching.first?.note, "循环观点")
    }

    func testAddHighlightPersistsHighlights() async throws {
        let item = makeStoreItem(id: "highlight-item", title: "Highlight item")
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(repository: repository, items: [item], selectedItemID: item.id)

        store.addHighlight(itemID: item.id, quote: "  important quote  ", note: "note")
        await store.flushPendingPersistence()

        let saved = try await repository.loadLibrary().items.first
        XCTAssertEqual(saved?.highlights.first?.quote, "important quote")
        XCTAssertEqual(saved?.highlights.first?.note, "note")
    }

    func testPreferencesPersistToUserDefaults() {
        let suiteName = "ReaderStoreTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = ReaderStore(userDefaults: userDefaults)

        store.themeMode = .dark
        store.useSerif = false
        store.fontSize = 21
        store.lineHeight = 2.0
        store.readingWidth = 760
        store.bilingual = false

        let reloaded = ReaderStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.themeMode, .dark)
        XCTAssertFalse(reloaded.useSerif)
        XCTAssertEqual(reloaded.fontSize, 21)
        XCTAssertEqual(reloaded.lineHeight, 2.0)
        XCTAssertEqual(reloaded.readingWidth, 760)
        XCTAssertFalse(reloaded.bilingual)
    }

    func testSavingAIConfigurationKeepsProviderKeysSeparate() throws {
        let suiteName = "ReaderStoreTests-AI-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let settings = AISettings(userDefaults: userDefaults)
        let keyStoreProvider = StoreTestKeyStoreProvider()
        let store = ReaderStore(
            items: [],
            selectedItemID: nil,
            keyStoreProvider: keyStoreProvider,
            aiSettings: settings
        )

        try store.saveAIConfiguration(
            apiKey: "anthropic-key-1234",
            provider: .anthropic,
            anthropicModel: .default,
            openAIModel: .default,
            customProviderName: "",
            customBaseURLString: "",
            customModel: ""
        )
        try store.saveAIConfiguration(
            apiKey: "openai-key-5678",
            provider: .openAI,
            anthropicModel: .default,
            openAIModel: .default,
            customProviderName: "",
            customBaseURLString: "",
            customModel: ""
        )

        XCTAssertEqual(try keyStoreProvider.store(for: .anthropic).loadAPIKey(), "anthropic-key-1234")
        XCTAssertEqual(try keyStoreProvider.store(for: .openAI).loadAPIKey(), "openai-key-5678")
        XCTAssertEqual(store.maskedAPIKey(for: .anthropic), "••••1234")
        XCTAssertEqual(store.maskedAPIKey(for: .openAI), "••••5678")
    }

    func testSelectionTranslateOpensTranslateTabWithContext() {
        let store = ReaderStore()
        store.aiPanelOpen = false
        store.aiTab = .summary

        store.translateSelection("  Local-first software  ")

        XCTAssertTrue(store.aiPanelOpen)
        XCTAssertEqual(store.aiTab, .translate)
        XCTAssertEqual(store.pendingTranslationText, "Local-first software")
    }

    func testSelectionAskOpensChatWithSelectedText() {
        let store = ReaderStore()
        store.aiPanelOpen = false
        store.aiTab = .summary
        let initialCount = store.chatMessages.count

        store.askAboutSelection("验证机制")

        XCTAssertTrue(store.aiPanelOpen)
        XCTAssertEqual(store.aiTab, .chat)
        XCTAssertEqual(store.chatMessages.count, initialCount + 1)
        XCTAssertEqual(store.chatMessages.last?.role, .user)
        XCTAssertTrue(store.chatMessages.last?.text.contains("验证机制") == true)
    }

    func testSendMessageStreamsAssistantReply() async {
        let item = makeStoreItem(id: "chat-item", title: "Chat Item")
        let store = ReaderStore(
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(
                isConfigured: true,
                summary: ReaderSummary(text: [], keys: [], tagSuggestions: []),
                chatTokens: ["流式", "回答"]
            )
        )

        store.sendMessage("解释正文")
        await store.waitForChatResponse()

        XCTAssertFalse(store.isSendingMessage)
        XCTAssertEqual(store.chatMessages.suffix(2).map(\.role), [.user, .assistant])
        XCTAssertEqual(store.chatMessages.last?.text, "流式回答")
    }

    func testSelectingItemCancelsInFlightChat() async {
        let first = makeStoreItem(id: "chat-first", title: "First")
        let second = makeStoreItem(id: "chat-second", title: "Second")
        let store = ReaderStore(
            items: [first, second],
            selectedItemID: first.id,
            aiService: HangingAIService()
        )

        store.sendMessage("继续解释")
        XCTAssertTrue(store.isSendingMessage)

        store.selectItem(second.id)
        await store.waitForChatResponse()

        XCTAssertFalse(store.isSendingMessage)
        XCTAssertNil(store.chatError)
    }

    func testGenerateRemixStreamsDraftWithoutPersisting() async throws {
        let item = makeStoreItem(id: "remix-item", title: "Remix Item")
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(
            repository: repository,
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(
                isConfigured: true,
                summary: ReaderSummary(text: [], keys: [], tagSuggestions: []),
                remixTokens: ["# 草稿", "\n正文"]
            )
        )

        store.generateRemix(type: "rx-note", selectedSourceIDs: [item.id])
        await store.waitForRemixGeneration()

        XCTAssertFalse(store.isGeneratingRemix)
        XCTAssertEqual(store.remixOutput, "# 草稿\n正文")
        let saved = try await repository.loadLibrary().items.first { $0.id == item.id }
        XCTAssertEqual(saved?.body.first?.text, item.body.first?.text)
    }

    func testUnconfiguredChatAndRemixDoNotGenerateFakeText() async {
        let item = makeStoreItem(id: "unconfigured-chat-remix", title: "No AI")
        let store = ReaderStore(
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(
                isConfigured: false,
                summary: ReaderSummary(text: [], keys: [], tagSuggestions: []),
                chatTokens: ["不应出现"],
                remixTokens: ["不应出现"]
            )
        )

        store.sendMessage("问题")
        await store.waitForChatResponse()
        store.generateRemix(type: "rx-note", selectedSourceIDs: [item.id])
        await store.waitForRemixGeneration()

        XCTAssertEqual(store.chatMessages.last?.role, .user)
        XCTAssertTrue(store.aiSettingsSheetOpen)
        XCTAssertEqual(store.chatError, AIError.notConfigured.localizedDescription)
        XCTAssertEqual(store.remixOutput, "")
        XCTAssertEqual(store.remixError, AIError.notConfigured.localizedDescription)
    }

    func testGenerateSummaryPersistsWithMockAIService() async throws {
        let item = makeStoreItem(id: "summary-item", title: "Summary Item")
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let summary = ReaderSummary(
            text: ["真实 AI 摘要"],
            keys: ["结构化", "落库", "本地"],
            tagSuggestions: ["AI", "Reader"]
        )
        let store = ReaderStore(
            repository: repository,
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(isConfigured: true, summary: summary)
        )

        store.generateSummary(for: item.id)
        await store.waitForSummaryGeneration()
        await store.flushPendingPersistence()

        XCTAssertEqual(store.items.first?.summary, summary)
        let saved = try await repository.loadLibrary().items.first { $0.id == item.id }
        XCTAssertEqual(saved?.summary, summary)
    }

    func testUnconfiguredAIDoesNotGenerateFakeSummary() async {
        let item = makeStoreItem(id: "unconfigured-summary", title: "Unconfigured")
        let store = ReaderStore(
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(isConfigured: false, summary: ReaderSummary(text: ["不应出现"], keys: [], tagSuggestions: []))
        )

        store.generateSummary(for: item.id)
        await store.waitForSummaryGeneration()

        XCTAssertEqual(store.items.first?.summary, item.summary)
        XCTAssertTrue(store.aiSettingsSheetOpen)
        XCTAssertEqual(store.summaryGenerationError, AIError.notConfigured.localizedDescription)
    }

    func testTranslateArticlePersistsBlockTranslations() async throws {
        let item = makeStoreItem(id: "translate-item", title: "Translate Item")
        let blockID = try XCTUnwrap(item.body.first?.id.uuidString)
        let repository = InMemoryRepository(snapshot: LibrarySnapshot(items: [item], tags: [], folders: [], platforms: []))
        let store = ReaderStore(
            repository: repository,
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(
                isConfigured: true,
                summary: ReaderSummary(text: [], keys: [], tagSuggestions: []),
                translations: [blockID: "Translated paragraph"]
            )
        )

        store.translateArticle(itemID: item.id, to: "en")
        await store.waitForTranslation()
        await store.flushPendingPersistence()

        XCTAssertEqual(store.items.first?.body.first?.translation, "Translated paragraph")
        let saved = try await repository.loadLibrary().items.first { $0.id == item.id }
        XCTAssertEqual(saved?.body.first?.translation, "Translated paragraph")
        XCTAssertTrue(store.bilingual)
    }

    func testTranslateSelectionStoresVisibleResultOnly() async throws {
        let item = makeStoreItem(id: "selection-translate", title: "Selection Translate")
        let store = ReaderStore(
            items: [item],
            selectedItemID: item.id,
            aiService: SelectionAIService()
        )

        store.translateSelection("  Local-first software  ")
        await store.waitForSelectionTranslation()

        XCTAssertEqual(store.pendingTranslationText, "Local-first software")
        XCTAssertEqual(store.pendingTranslationResult, "选区译文")
        XCTAssertEqual(store.items.first?.body.first?.translation, "")
    }

    func testUnconfiguredTranslationDoesNotGenerateFakeText() async {
        let item = makeStoreItem(id: "unconfigured-translation", title: "No Translation")
        let store = ReaderStore(
            items: [item],
            selectedItemID: item.id,
            aiService: MockAIService(
                isConfigured: false,
                summary: ReaderSummary(text: [], keys: [], tagSuggestions: []),
                translations: [item.body[0].id.uuidString: "不应出现"]
            )
        )

        store.translateArticle(itemID: item.id)
        await store.waitForTranslation()

        XCTAssertEqual(store.items.first?.body.first?.translation, "")
        XCTAssertTrue(store.aiSettingsSheetOpen)
        XCTAssertEqual(store.translationError, AIError.notConfigured.localizedDescription)
    }

    func testCaptureURLPreviewAndSaveSelectsNewInboxItem() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let articleURL = URL(string: "https://news.example.com/archive/story")!
        let repository = InMemoryRepository(snapshot: .empty)
        let captureService = CaptureService(
            repository: repository,
            httpClient: StoreFixtureHTTPClient(responses: [
                articleURL.absoluteString: CaptureResponse(
                    url: articleURL,
                    mimeType: "text/html",
                    textEncodingName: "utf-8",
                    data: try fixtureData("news-with-cover")
                )
            ]),
            assetStore: LocalCaptureAssetStore(rootDirectory: rootDirectory)
        )
        let store = ReaderStore(
            repository: repository,
            items: [],
            selectedItemID: nil,
            captureService: captureService
        )

        let preview = try await store.captureURLPreview(articleURL.absoluteString)
        let saved = try await store.saveCapturedArticle(preview, tagIDs: ["t-ai"], folderID: "fo-ai")

        XCTAssertEqual(store.selectedItemID, saved.id)
        XCTAssertEqual(store.activeViewID, "inbox")
        XCTAssertEqual(store.items.first?.url, articleURL.absoluteString)
        XCTAssertEqual(store.items.first?.tagIDs, ["t-ai"])
        let persisted = try await repository.loadLibrary().items.first
        XCTAssertEqual(persisted?.id, saved.id)
    }

    private func makeStoreItem(
        id: String,
        title: String,
        isFavorite: Bool = false,
        isUnread: Bool = true
    ) -> ReaderItem {
        ReaderItem(
            id: id,
            type: "article",
            kind: .web,
            source: "Tests",
            author: "Tester",
            title: title,
            excerpt: "Excerpt",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            readingTime: 1,
            language: "zh",
            tagIDs: [],
            folderID: "",
            isFavorite: isFavorite,
            isUnread: isUnread,
            progress: 0,
            hue: 120,
            hasCover: false,
            body: [ContentBlock(kind: .paragraph, language: "zh", text: "正文")],
            summary: ReaderSummary(text: [], keys: [], tagSuggestions: [])
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try Data(contentsOf: url)
    }
}

private struct StoreFixtureHTTPClient: HTTPClient {
    var responses: [String: CaptureResponse]

    func fetch(_ request: CaptureRequest) async throws -> CaptureResponse {
        guard let response = responses[request.url.absoluteString] else {
            throw HTTPClientError.badStatus(404)
        }
        return response
    }
}

private final class StoreTestKeyStoreProvider: AIKeyStoreProviding, @unchecked Sendable {
    private let stores: [AIProvider: StoreTestKeyStore]

    init() {
        stores = Dictionary(uniqueKeysWithValues: AIProvider.allCases.map { ($0, StoreTestKeyStore()) })
    }

    func keyStore(for provider: AIProvider) -> any APIKeyStoring {
        store(for: provider)
    }

    func store(for provider: AIProvider) -> StoreTestKeyStore {
        stores[provider]!
    }
}

private final class StoreTestKeyStore: APIKeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

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

private struct MockAIService: AIService {
    var isConfigured: Bool
    var summary: ReaderSummary
    var translations: [String: String] = [:]
    var chatTokens: [String] = []
    var remixTokens: [String] = []

    func validateConnection() async throws {}

    func summarize(_ item: ReaderItem) async throws -> ReaderSummary {
        summary
    }

    func translate(_ item: ReaderItem, to language: String) async throws -> [String: String] {
        guard isConfigured else { throw AIError.notConfigured }
        return translations
    }

    func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard isConfigured else {
                continuation.finish(throwing: AIError.notConfigured)
                return
            }
            for token in chatTokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard isConfigured else {
                continuation.finish(throwing: AIError.notConfigured)
                return
            }
            for token in remixTokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }
}

private struct HangingAIService: AIService {
    var isConfigured: Bool { true }

    func validateConnection() async throws {}

    func summarize(_ item: ReaderItem) async throws -> ReaderSummary {
        ReaderSummary(text: [], keys: [], tagSuggestions: [])
    }

    func translate(_ item: ReaderItem, to language: String) async throws -> [String: String] {
        [:]
    }

    func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                continuation.finish(throwing: CancellationError())
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private struct SelectionAIService: AIService {
    var isConfigured: Bool { true }

    func validateConnection() async throws {}

    func summarize(_ item: ReaderItem) async throws -> ReaderSummary {
        ReaderSummary(text: [], keys: [], tagSuggestions: [])
    }

    func translate(_ item: ReaderItem, to language: String) async throws -> [String: String] {
        guard let block = item.body.first else { return [:] }
        return [block.id.uuidString: "选区译文"]
    }

    func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
