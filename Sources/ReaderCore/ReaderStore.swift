import Combine
import Foundation

@MainActor
public final class ReaderStore: ObservableObject {
    @Published public var items: [ReaderItem]
    @Published public var activeViewID: String
    @Published public var selectedItemID: String?
    @Published public var query: String {
        didSet {
            if query != oldValue {
                scheduleSearch()
            }
        }
    }
    @Published public var sortMode: SortMode
    @Published public var themeMode: ReaderThemeMode {
        didSet {
            userDefaults.set(themeMode.rawValue, forKey: PreferenceKey.themeMode)
        }
    }
    @Published public var aiPanelOpen: Bool
    @Published public var aiTab: AITab
    @Published public var chatMessages: [ChatMessage]
    @Published public var isSendingMessage: Bool
    @Published public var useSerif: Bool {
        didSet {
            userDefaults.set(useSerif, forKey: PreferenceKey.useSerif)
        }
    }
    @Published public var fontSize: Double {
        didSet {
            userDefaults.set(fontSize, forKey: PreferenceKey.fontSize)
        }
    }
    @Published public var lineHeight: Double {
        didSet {
            userDefaults.set(lineHeight, forKey: PreferenceKey.lineHeight)
        }
    }
    @Published public var readingWidth: Double {
        didSet {
            userDefaults.set(readingWidth, forKey: PreferenceKey.readingWidth)
        }
    }
    @Published public var bilingual: Bool {
        didSet {
            userDefaults.set(bilingual, forKey: PreferenceKey.bilingual)
        }
    }
    @Published public var typographyOpen: Bool
    @Published public var commandPaletteOpen: Bool
    @Published public var addModalOpen: Bool
    @Published public var subscriptionsOpen: Bool
    @Published public var aiSettingsSheetOpen: Bool
    @Published public var onboardingOpen: Bool
    @Published public var onboardingStep: ReaderOnboardingStep
    @Published public var pendingDeleteItemID: String?
    @Published public var toastMessage: String?
    @Published public var pendingTranslationText: String?
    @Published public private(set) var pendingTranslationResult: String?
    @Published public private(set) var isTranslatingArticle: Bool
    @Published public private(set) var isTranslatingSelection: Bool
    @Published public private(set) var translationError: String?
    @Published public private(set) var chatError: String?
    @Published public private(set) var remixOutput: String
    @Published public private(set) var remixError: String?
    @Published public private(set) var isGeneratingRemix: Bool
    @Published public private(set) var isGeneratingSummary: Bool
    @Published public private(set) var summaryGenerationError: String?
    @Published public private(set) var aiConfigurationRevision: Int
    @Published public private(set) var isSyncingFeeds: Bool
    @Published public private(set) var feedSyncErrors: [String: String]
    @Published private var searchResultIDs: Set<String>?

    public let smartViews = SampleLibrary.smartViews
    @Published public private(set) var tags: [ReaderTag]
    @Published public private(set) var platforms: [PlatformSource]
    @Published public private(set) var folders: [ReaderFolder]
    public let chatSuggestions = SampleLibrary.chatSuggestions

    private let repository: any ReaderRepository
    private let captureService: CaptureService
    private let feedSyncService: FeedSyncService
    private let attachmentImporter: AttachmentImporter
    private let aiServiceOverride: (any AIService)?
    private let aiServiceFactory: any AIServiceMaking
    private let keyStoreProvider: any AIKeyStoreProviding
    private let aiSettings: AISettings
    private let userDefaults: UserDefaults
    private var toastTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var summaryTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var selectionTranslationTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var remixTask: Task<Void, Never>?
    private var feedSyncTimerTask: Task<Void, Never>?
    private var persistenceTasks: [Task<Void, Never>]
    private var readingStateSaveTasks: [String: Task<Void, Never>]
    private var readingOffsets: [String: Double]

    public init(
        repository: any ReaderRepository = InMemoryRepository(),
        userDefaults: UserDefaults = .standard,
        items: [ReaderItem] = SampleLibrary.items,
        tags: [ReaderTag] = SampleLibrary.tags,
        platforms: [PlatformSource] = SampleLibrary.platforms,
        folders: [ReaderFolder] = SampleLibrary.folders,
        activeViewID: String = "inbox",
        selectedItemID: String? = "a1",
        captureService: CaptureService? = nil,
        feedSyncService: FeedSyncService? = nil,
        attachmentImporter: AttachmentImporter? = nil,
        aiService: (any AIService)? = nil,
        apiKeyStore: (any APIKeyStoring)? = nil,
        keyStoreProvider: (any AIKeyStoreProviding)? = nil,
        aiServiceFactory: any AIServiceMaking = DefaultAIServiceFactory(),
        aiSettings: AISettings = AISettings(),
        loadOnInit: Bool = false
    ) {
        self.repository = repository
        self.captureService = captureService ?? CaptureService(repository: repository)
        self.feedSyncService = feedSyncService ?? FeedSyncService(repository: repository)
        self.attachmentImporter = attachmentImporter ?? ((try? AttachmentImporter()) ?? AttachmentImporter(rootDirectory: FileManager.default.temporaryDirectory))
        self.keyStoreProvider = keyStoreProvider ?? apiKeyStore.map { SingleAIKeyStoreProvider(store: $0) } ?? DefaultAIKeyStoreProvider()
        self.aiServiceFactory = aiServiceFactory
        self.aiSettings = aiSettings
        self.aiServiceOverride = aiService
        self.userDefaults = userDefaults
        self.items = items
        self.tags = tags
        self.platforms = platforms
        self.folders = folders
        self.activeViewID = activeViewID
        self.selectedItemID = selectedItemID
        self.query = ""
        self.sortMode = .newest
        self.themeMode = Self.themeMode(from: userDefaults)
        self.aiPanelOpen = true
        self.aiTab = .summary
        self.chatMessages = SampleLibrary.seedChat
        self.isSendingMessage = false
        self.useSerif = userDefaults.object(forKey: PreferenceKey.useSerif) as? Bool ?? true
        self.fontSize = Self.doublePreference(forKey: PreferenceKey.fontSize, defaultValue: 18, userDefaults: userDefaults)
        self.lineHeight = Self.doublePreference(forKey: PreferenceKey.lineHeight, defaultValue: 1.78, userDefaults: userDefaults)
        self.readingWidth = Self.doublePreference(forKey: PreferenceKey.readingWidth, defaultValue: 680, userDefaults: userDefaults)
        self.bilingual = userDefaults.object(forKey: PreferenceKey.bilingual) as? Bool ?? true
        self.typographyOpen = false
        self.commandPaletteOpen = false
        self.addModalOpen = false
        self.subscriptionsOpen = false
        self.aiSettingsSheetOpen = false
        self.onboardingOpen = !userDefaults.bool(forKey: PreferenceKey.onboardingCompleted)
        self.onboardingStep = .sidebar
        self.pendingDeleteItemID = nil
        self.toastMessage = nil
        self.pendingTranslationText = nil
        self.pendingTranslationResult = nil
        self.isTranslatingArticle = false
        self.isTranslatingSelection = false
        self.translationError = nil
        self.chatError = nil
        self.remixOutput = ""
        self.remixError = nil
        self.isGeneratingRemix = false
        self.isGeneratingSummary = false
        self.summaryGenerationError = nil
        self.aiConfigurationRevision = 0
        self.isSyncingFeeds = false
        self.feedSyncErrors = [:]
        self.searchResultIDs = nil
        self.persistenceTasks = []
        self.readingStateSaveTasks = [:]
        self.readingOffsets = [:]

        if loadOnInit {
            loadLibrary()
            startFeedSyncTimer()
        }
    }

    public func loadLibrary() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            do {
                try await self?.loadLibraryFromRepository()
            } catch {
                await MainActor.run {
                    self?.showToast("加载本地资料库失败")
                }
            }
        }
    }

    func loadLibraryFromRepository() async throws {
        let snapshot = try await repository.loadLibrary()
        apply(snapshot)
        scheduleAutomaticFeedSyncIfNeeded()
    }

    func flushPendingPersistence() async {
        let pendingReadingStateIDs = Array(readingStateSaveTasks.keys)
        for id in pendingReadingStateIDs {
            readingStateSaveTasks[id]?.cancel()
            readingStateSaveTasks[id] = nil
            saveReadingStateNow(for: id)
        }

        while !persistenceTasks.isEmpty {
            let tasks = persistenceTasks
            persistenceTasks.removeAll()
            for task in tasks {
                await task.value
            }
        }
    }

    func waitForSearch() async {
        await searchTask?.value
    }

    func waitForSummaryGeneration() async {
        await summaryTask?.value
    }

    func waitForTranslation() async {
        await translationTask?.value
    }

    func waitForSelectionTranslation() async {
        await selectionTranslationTask?.value
    }

    func waitForChatResponse() async {
        await chatTask?.value
    }

    func waitForRemixGeneration() async {
        await remixTask?.value
    }

    public var selectedItem: ReaderItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    public var pendingDeleteItem: ReaderItem? {
        guard let pendingDeleteItemID else { return nil }
        return items.first { $0.id == pendingDeleteItemID }
    }

    private var currentAPIKeyStore: any APIKeyStoring {
        keyStoreProvider.keyStore(for: aiSettings.selectedProvider)
    }

    private var currentAIService: any AIService {
        if let aiServiceOverride {
            return aiServiceOverride
        }
        return aiServiceFactory.makeService(
            configuration: aiSettings.currentProviderConfiguration,
            settings: aiSettings,
            keyStore: currentAPIKeyStore
        )
    }

    public var isAIConfigured: Bool {
        currentAIService.isConfigured
    }

    public var selectedAIProvider: AIProvider {
        aiSettings.selectedProvider
    }

    public var selectedAIModel: AnthropicModel {
        aiSettings.selectedModel
    }

    public var anthropicBaseURLString: String {
        aiSettings.anthropicBaseURLString
    }

    public var anthropicAuthMode: AnthropicAuthMode {
        aiSettings.anthropicAuthMode
    }

    public var anthropicCustomModel: String {
        aiSettings.anthropicCustomModel
    }

    public var anthropicBeta: String {
        aiSettings.anthropicBeta
    }

    public var selectedOpenAIModel: OpenAIModel {
        aiSettings.selectedOpenAIModel
    }

    public var customProviderName: String {
        aiSettings.customProviderName
    }

    public var customBaseURLString: String {
        aiSettings.customBaseURLString
    }

    public var customModel: String {
        aiSettings.customModel
    }

    public var currentAIProviderConfiguration: AIProviderConfiguration {
        aiSettings.currentProviderConfiguration
    }

    public var maskedAPIKey: String? {
        try? currentAPIKeyStore.maskedAPIKey()
    }

    public func maskedAPIKey(for provider: AIProvider) -> String? {
        try? keyStoreProvider.keyStore(for: provider).maskedAPIKey()
    }

    public var visibleItems: [ReaderItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = items.filter { item in
            inView(item, activeViewID)
        }

        if !trimmedQuery.isEmpty {
            let ftsMatches = searchResultIDs
            result = result.filter { item in
                searchText(for: item).lowercased().contains(trimmedQuery) || (ftsMatches?.contains(item.id) == true)
            }
        }

        switch sortMode {
        case .newest:
            result.sort { $0.publishedAt > $1.publishedAt }
        case .oldest:
            result.sort { $0.publishedAt < $1.publishedAt }
        case .unread:
            result.sort {
                if $0.isUnread != $1.isUnread { return $0.isUnread && !$1.isUnread }
                return $0.publishedAt > $1.publishedAt
            }
        }

        return result
    }

    public var activeViewName: String {
        name(for: activeViewID) ?? "全部"
    }

    public var activeSubtitle: String {
        let list = visibleItems
        let unreadCount = list.filter(\.isUnread).count
        if unreadCount > 0 {
            return "\(list.count) 篇 · \(unreadCount) 未读 · \(sortMode.title)"
        }
        return "\(list.count) 篇 · \(sortMode.title)"
    }

    public var feedsByID: [String: Feed] {
        Dictionary(uniqueKeysWithValues: platforms.flatMap(\.feeds).map { ($0.id, $0) })
    }

    public func name(for id: String) -> String? {
        if let smart = smartViews.first(where: { $0.id == id }) { return smart.name }
        if let platform = platforms.first(where: { $0.id == id }) { return platform.name }
        if let feed = platforms.flatMap(\.feeds).first(where: { $0.id == id }) { return feed.name }
        if let folder = allFolders.first(where: { $0.id == id }) { return folder.name }
        if let tag = tags.first(where: { $0.id == id }) { return tag.name }
        return nil
    }

    public func count(forSmartView id: String, fallback: Int) -> Int {
        switch id {
        case "all":
            return items.count
        case "unread":
            return items.filter(\.isUnread).count
        case "fav":
            return items.filter(\.isFavorite).count
        case "inbox":
            return items.filter { $0.isUnread || ($0.progress > 0 && $0.progress < 1) }.count
        case "later":
            return items.filter { $0.progress > 0 && $0.progress < 1 }.count
        default:
            return fallback
        }
    }

    public func tagCount(_ tagID: String) -> Int {
        items.filter { $0.tagIDs.contains(tagID) }.count
    }

    public func selectView(_ id: String) {
        activeViewID = id
        query = ""
        if let first = visibleItems.first, !visibleItems.contains(where: { $0.id == selectedItemID }) {
            selectItem(first.id)
        }
    }

    public func selectItem(_ id: String) {
        if selectedItemID != id {
            resetSelectionTransientState()
        }
        selectedItemID = id
        let updated = updateItem(id, mutate: { item in
            item.isUnread = false
        })
        if updated != nil {
            persist { repository in
                try await repository.setItemFlags(id: id, isUnread: false, isFavorite: nil)
            }
        }
    }

    @discardableResult
    public func selectNextVisibleItem() -> Bool {
        selectVisibleItem(offset: 1)
    }

    @discardableResult
    public func selectPreviousVisibleItem() -> Bool {
        selectVisibleItem(offset: -1)
    }

    @discardableResult
    public func toggleFavoriteOfSelectedItem() -> Bool {
        guard let selectedItemID else { return false }
        toggleFavorite(selectedItemID)
        return true
    }

    @discardableResult
    public func requestDeleteSelectedItem() -> Bool {
        guard let selectedItemID else { return false }
        return requestDeleteItem(selectedItemID)
    }

    @discardableResult
    public func requestDeleteItem(_ id: String) -> Bool {
        guard items.contains(where: { $0.id == id }) else { return false }
        pendingDeleteItemID = id
        return true
    }

    public func cancelDeleteRequest() {
        pendingDeleteItemID = nil
    }

    public func confirmPendingDelete() {
        guard let id = pendingDeleteItemID else { return }
        pendingDeleteItemID = nil
        deleteItem(id)
    }

    public func deleteItem(_ id: String) {
        let visibleBeforeDelete = visibleItems
        let visibleIndex = visibleBeforeDelete.firstIndex { $0.id == id }
        guard let itemIndex = items.firstIndex(where: { $0.id == id }) else { return }

        let deletedTitle = items[itemIndex].title
        let shouldReselect = selectedItemID == id
        let replacementID: String?
        if shouldReselect, let visibleIndex {
            replacementID = visibleBeforeDelete[safe: visibleIndex + 1]?.id ?? visibleBeforeDelete[safe: visibleIndex - 1]?.id
        } else {
            replacementID = nil
        }

        items.remove(at: itemIndex)
        readingOffsets[id] = nil
        readingStateSaveTasks[id]?.cancel()
        readingStateSaveTasks[id] = nil
        searchResultIDs?.remove(id)

        if pendingDeleteItemID == id {
            pendingDeleteItemID = nil
        }

        if shouldReselect {
            resetSelectionTransientState()
            selectedItemID = nil
            if let replacementID, items.contains(where: { $0.id == replacementID }) {
                selectItem(replacementID)
            }
        }

        persist(onErrorMessage: "删除条目失败") { repository in
            try await repository.deleteItem(id: id)
        }
        showToast("已删除 · \(deletedTitle)")
    }

    public func toggleFavorite(_ id: String) {
        guard let updated = updateItem(id, mutate: { item in
            item.isFavorite.toggle()
        }) else {
            return
        }
        persist { repository in
            try await repository.setItemFlags(id: id, isUnread: nil, isFavorite: updated.isFavorite)
        }
    }

    public func setProgress(_ id: String, progress: Double) {
        guard updateItem(id, mutate: { item in
            item.progress = min(max(progress, 0), 1)
        }) != nil else {
            return
        }
        scheduleReadingStateSave(for: id)
    }

    public func setReadingOffset(_ id: String, offset: Double) {
        readingOffsets[id] = max(0, offset)
        scheduleReadingStateSave(for: id)
    }

    public func readingOffset(for id: String) -> Double {
        readingOffsets[id] ?? 0
    }

    public func markAllRead() {
        let ids = items.map(\.id)
        for index in items.indices {
            items[index].isUnread = false
        }
        for id in ids {
            persist { repository in
                try await repository.setItemFlags(id: id, isUnread: false, isFavorite: nil)
            }
        }
        showToast("已全部标为已读")
    }

    public func cycleSortMode() {
        let all = SortMode.allCases
        guard let currentIndex = all.firstIndex(of: sortMode) else {
            sortMode = .newest
            return
        }
        sortMode = all[(currentIndex + 1) % all.count]
    }

    public func addHighlight(itemID: String, quote: String, note: String = "") {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateItem(itemID, mutate: { item in
            item.highlights.removeAll { $0.quote == trimmed }
            item.highlights.append(Highlight(quote: trimmed, note: note))
        }).map { item in
            persist { repository in
                try await repository.saveHighlights(itemID: itemID, item.highlights)
            }
        }
        showToast(note.isEmpty ? "已高亮" : "已保存高亮 + 笔记")
    }

    public func addItem(from draft: AddContentDraft) {
        guard draft.mode != "url" else {
            showToast("请先抓取网址")
            return
        }
        guard draft.mode != "file" else {
            showToast("请选择附件文件")
            return
        }

        let normalizedURL = draft.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = Self.domain(from: normalizedURL)
        let id = UUID().uuidString
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hue = Double(180 + ((normalizedURL.count + title.count) % 160))
        let publishedAt = Date()
        let emptySummary = ReaderSummary(text: [], keys: [], tagSuggestions: [])
        let bodyText = draft.markdown.trimmingCharacters(in: .whitespacesAndNewlines)

        let item: ReaderItem
        switch draft.mode {
        case "md":
            item = ReaderItem(
                id: id,
                type: "note",
                kind: .markdown,
                source: "我的笔记",
                author: "我",
                title: title.isEmpty ? "无标题笔记" : title,
                excerpt: bodyText.isEmpty ? "一篇 Markdown 笔记" : String(bodyText.prefix(80)),
                publishedAt: publishedAt,
                readingTime: 2,
                language: "zh",
                tagIDs: draft.tagIDs,
                folderID: draft.folderID,
                isFavorite: false,
                isUnread: true,
                progress: 0,
                hue: hue,
                hasCover: false,
                body: [
                    ContentBlock(kind: .paragraph, language: "zh", text: bodyText.isEmpty ? "（空白笔记）" : bodyText)
                ],
                summary: emptySummary
            )
        case "file":
            item = ReaderItem(
                id: id,
                type: "pdf",
                kind: .pdf,
                source: "附件 · PDF",
                author: "本地文件",
                title: title.isEmpty ? "新附件.pdf" : title,
                excerpt: "已导入本地附件,可提取全文做摘要与问答。",
                publishedAt: publishedAt,
                readingTime: 10,
                language: "zh",
                tagIDs: draft.tagIDs,
                folderID: draft.folderID,
                isFavorite: false,
                isUnread: true,
                progress: 0,
                hue: hue,
                hasCover: false,
                body: [
                    ContentBlock(kind: .paragraph, language: "zh", text: "附件已保存到本地。")
                ],
                summary: emptySummary
            )
        default:
            item = ReaderItem(
                id: id,
                type: "article",
                kind: .web,
                source: domain,
                author: domain,
                title: title.isEmpty ? "来自 \(domain) 的文章" : title,
                excerpt: "已自动抓取正文与配图,可立即阅读、翻译或摘要。",
                publishedAt: publishedAt,
                readingTime: 6,
                language: "zh",
                tagIDs: draft.tagIDs,
                folderID: draft.folderID,
                isFavorite: false,
                isUnread: true,
                progress: 0,
                hue: hue,
                hasCover: true,
                body: [
                    ContentBlock(kind: .lead, language: "zh", text: "这是从 \(domain) 抓取的内容正文。Reader 已保存全文与图片到本地。")
                ],
                summary: emptySummary
            )
        }

        items.insert(item, at: 0)
        addModalOpen = false
        activeViewID = "inbox"
        selectedItemID = item.id
        persist { repository in
            try await repository.saveItem(item)
        }
        showToast("已保存到本地 · \(item.source)")
    }

    public func captureURLPreview(_ url: String) async throws -> CapturedArticle {
        try await captureService.preview(urlString: url)
    }

    @discardableResult
    public func saveCapturedArticle(_ article: CapturedArticle, tagIDs: [String], folderID: String) async throws -> ReaderItem {
        let item = try await captureService.save(article, tagIDs: tagIDs, folderID: folderID)
        items.insert(item, at: 0)
        addModalOpen = false
        activeViewID = "inbox"
        selectedItemID = item.id
        showToast("已保存到本地 · \(item.source)")
        return item
    }

    public func addRSSFeed(_ url: String) async {
        isSyncingFeeds = true
        defer { isSyncingFeeds = false }

        do {
            let feed = try await feedSyncService.addFeed(urlString: url)
            let summary = await feedSyncService.syncAll(feeds: [feed])
            try await loadLibraryFromRepository()
            applyFeedSyncSummary(summary)
            if summary.failureCount > 0 {
                showToast("订阅已添加,同步失败")
            } else {
                showToast("已同步 \(summary.insertedCount) 篇新条目")
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// Imports an OPML subscription export: adds the new feeds, skips duplicates, and
    /// syncs the additions to pull their latest articles.
    @discardableResult
    public func importOPML(_ data: Data) async -> OPMLImportSummary {
        isSyncingFeeds = true
        defer { isSyncingFeeds = false }

        let existing = Set(platforms.flatMap { $0.feeds.map(\.id) })
        do {
            let summary = try await feedSyncService.importOPML(data, existingFeedIDs: existing)
            try await loadLibraryFromRepository()
            if summary.added == 0 {
                showToast(summary.skipped > 0 ? "这些订阅源都已存在" : "没有可导入的订阅源")
            } else {
                showToast("已导入 \(summary.added) 个订阅源 · \(summary.insertedItems) 篇新条目")
            }
            return summary
        } catch {
            showToast(error.localizedDescription)
            return OPMLImportSummary()
        }
    }

    /// Imports a read-later export (Pocket / Instapaper / URL list) as summary-only
    /// items, skipping URLs already in the library.
    @discardableResult
    public func importReadLater(_ data: Data, source: ReadLaterSource? = nil) async -> ReadLaterImportSummary {
        isSyncingFeeds = true
        defer { isSyncingFeeds = false }

        let entries: [ReadLaterEntry]
        do {
            entries = try ReadLaterImporter().parse(data, source: source)
        } catch {
            showToast(error.localizedDescription)
            return ReadLaterImportSummary()
        }
        guard !entries.isEmpty else {
            showToast("没有找到可导入的链接")
            return ReadLaterImportSummary()
        }

        let existing = Set(items.compactMap(\.url))
        let summary = await captureService.importReadLater(entries, existingURLs: existing)
        try? await loadLibraryFromRepository()
        if summary.added == 0 {
            showToast(summary.skipped > 0 ? "这些内容都已在库中" : "没有可导入的内容")
        } else {
            showToast("已导入 \(summary.added) 篇内容")
        }
        return summary
    }

    public func syncFeeds() {
        Task {
            await syncFeedsNow(showToastOnCompletion: true)
        }
    }

    public func fetchFullArticle(for id: String) {
        guard let item = items.first(where: { $0.id == id }), let url = item.url else {
            showToast("条目没有原文链接")
            return
        }

        Task {
            do {
                let article = try await captureService.preview(urlString: url)
                guard let index = items.firstIndex(where: { $0.id == id }) else { return }
                items[index].title = article.title
                items[index].excerpt = article.excerpt
                items[index].author = article.author
                items[index].publishedAt = article.publishedAt
                items[index].readingTime = article.readingTime
                items[index].language = article.language
                items[index].hue = article.hue
                items[index].coverPath = article.coverPath
                items[index].hasCover = article.coverPath != nil
                items[index].body = article.body
                items[index].summary.keys.removeAll { $0 == ReaderSummary.summaryOnlyMarker }
                let updated = items[index]
                persist { repository in
                    try await repository.saveItem(updated)
                }
                showToast("已抓取全文")
            } catch {
                showToast(error.localizedDescription)
            }
        }
    }

    public func openAISettings() {
        aiSettingsSheetOpen = true
    }

    public func openOnboarding() {
        closeTransientOverlaysForOnboarding()
        onboardingStep = .sidebar
        prepareForOnboardingStep()
        onboardingOpen = true
    }

    public func advanceOnboarding() {
        guard let currentIndex = ReaderOnboardingStep.allCases.firstIndex(of: onboardingStep) else {
            onboardingStep = .sidebar
            return
        }

        let nextIndex = currentIndex + 1
        if ReaderOnboardingStep.allCases.indices.contains(nextIndex) {
            onboardingStep = ReaderOnboardingStep.allCases[nextIndex]
            prepareForOnboardingStep()
        } else {
            completeOnboarding()
        }
    }

    public func retreatOnboarding() {
        guard let currentIndex = ReaderOnboardingStep.allCases.firstIndex(of: onboardingStep) else {
            onboardingStep = .sidebar
            return
        }
        let previousIndex = currentIndex - 1
        guard ReaderOnboardingStep.allCases.indices.contains(previousIndex) else { return }
        onboardingStep = ReaderOnboardingStep.allCases[previousIndex]
        prepareForOnboardingStep()
    }

    public func skipOnboarding() {
        completeOnboarding()
    }

    public func completeOnboarding() {
        onboardingOpen = false
        userDefaults.set(true, forKey: PreferenceKey.onboardingCompleted)
    }

    public func selectAIProvider(_ provider: AIProvider) {
        aiSettings.selectedProvider = provider
        refreshAIConfiguration()
    }

    public func saveAIConfiguration(
        apiKey: String,
        provider: AIProvider,
        anthropicModel: AnthropicModel,
        anthropicBaseURLString: String,
        anthropicAuthMode: AnthropicAuthMode,
        anthropicCustomModel: String,
        anthropicBeta: String,
        openAIModel: OpenAIModel,
        customProviderName: String,
        customBaseURLString: String,
        customModel: String
    ) throws {
        aiSettings.selectedProvider = provider
        aiSettings.selectedModel = anthropicModel
        aiSettings.anthropicBaseURLString = anthropicBaseURLString
        aiSettings.anthropicAuthMode = anthropicAuthMode
        aiSettings.anthropicCustomModel = anthropicCustomModel
        aiSettings.anthropicBeta = anthropicBeta
        aiSettings.selectedOpenAIModel = openAIModel
        aiSettings.customProviderName = customProviderName
        aiSettings.customBaseURLString = customBaseURLString
        aiSettings.customModel = customModel

        let keyStore = keyStoreProvider.keyStore(for: provider)
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            try keyStore.saveAPIKey(trimmed)
        }

        guard keyStore.hasAPIKey, aiSettings.configuration(for: provider).baseURL != nil else {
            aiSettings.isEnabled = false
            refreshAIConfiguration()
            throw AIError.notConfigured
        }

        aiSettings.isEnabled = true
        refreshAIConfiguration()
        showToast("AI 已连接")
    }

    public func saveAIConfiguration(apiKey: String, model: AnthropicModel) throws {
        try saveAIConfiguration(
            apiKey: apiKey,
            provider: .anthropic,
            anthropicModel: model,
            anthropicBaseURLString: aiSettings.anthropicBaseURLString,
            anthropicAuthMode: aiSettings.anthropicAuthMode,
            anthropicCustomModel: aiSettings.anthropicCustomModel,
            anthropicBeta: aiSettings.anthropicBeta,
            openAIModel: aiSettings.selectedOpenAIModel,
            customProviderName: aiSettings.customProviderName,
            customBaseURLString: aiSettings.customBaseURLString,
            customModel: aiSettings.customModel
        )
    }

    public func removeAIConfiguration() throws {
        try currentAPIKeyStore.deleteAPIKey()
        aiSettings.isEnabled = false
        refreshAIConfiguration()
        showToast("AI 已断开")
    }

    public func refreshAIConfiguration() {
        aiConfigurationRevision += 1
    }

    public func testAIConnection() async throws -> AIConnectionTestResult {
        let result = try await currentAIService.validateConnection()
        showToast("AI 连接正常 · \(result.model) · \(result.elapsedMilliseconds)ms")
        return result
    }

    public func generateSummary(for id: String? = nil) {
        let itemID = id ?? selectedItemID
        guard let itemID, let item = items.first(where: { $0.id == itemID }) else { return }

        aiPanelOpen = true
        aiTab = .summary

        let aiService = currentAIService
        guard aiService.isConfigured else {
            summaryGenerationError = AIError.notConfigured.localizedDescription
            aiSettingsSheetOpen = true
            showToast(AIError.notConfigured.localizedDescription)
            return
        }

        summaryTask?.cancel()
        isGeneratingSummary = true
        summaryGenerationError = nil

        summaryTask = Task { [weak self, aiService] in
            do {
                let summary = try await aiService.summarize(item)
                await MainActor.run {
                    guard let self else { return }
                    if let updated = self.updateItem(itemID, mutate: { item in
                        item.summary = summary
                    }) {
                        self.persist { repository in
                            try await repository.saveItem(updated)
                        }
                    }
                    self.isGeneratingSummary = false
                    self.showToast("摘要已保存到本地")
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    let message = Self.userFacingAIMessage(error)
                    self?.summaryGenerationError = message
                    self?.isGeneratingSummary = false
                    self?.showToast(message)
                }
            }
        }
    }

    public func importAttachment(at url: URL, tagIDs: [String], folderID: String) async {
        do {
            let item = try await attachmentImporter.importFile(at: url, tagIDs: tagIDs, folderID: folderID)
            try await repository.saveItem(item)
            items.insert(item, at: 0)
            addModalOpen = false
            activeViewID = "inbox"
            selectedItemID = item.id
            showToast("已导入附件 · \(item.title)")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        aiPanelOpen = true
        aiTab = .chat
        chatError = nil
        chatMessages.append(ChatMessage(role: .user, text: trimmed))

        let aiService = currentAIService
        guard aiService.isConfigured else {
            chatError = AIError.notConfigured.localizedDescription
            showToast(AIError.notConfigured.localizedDescription)
            aiSettingsSheetOpen = true
            return
        }

        chatTask?.cancel()
        isSendingMessage = true
        let assistantID = UUID()
        chatMessages.append(ChatMessage(id: assistantID, role: .assistant, text: ""))
        let messages = chatMessages
        let item = selectedItem

        chatTask = Task { [weak self, aiService] in
            do {
                for try await token in aiService.chat(messages: messages, about: item) {
                    await MainActor.run {
                        self?.appendChatToken(token, to: assistantID)
                    }
                }
                await MainActor.run {
                    self?.isSendingMessage = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    let message = Self.userFacingAIMessage(error)
                    self?.chatError = message
                    self?.removeEmptyAssistantMessage(id: assistantID)
                    self?.isSendingMessage = false
                    self?.showToast(message)
                }
            }
        }
    }

    public func askAboutSelection(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sendMessage("关于这段的疑问:“\(trimmed)”")
    }

    public func translateSelection(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        pendingTranslationText = trimmed
        pendingTranslationResult = nil
        translationError = nil
        aiPanelOpen = true
        aiTab = .translate

        let aiService = currentAIService
        guard aiService.isConfigured else {
            showToast(AIError.notConfigured.localizedDescription)
            aiSettingsSheetOpen = true
            return
        }

        translateSelectionNow(trimmed)
    }

    public func translateSelectedArticle(to language: String? = nil) {
        guard let item = selectedItem else { return }
        translateArticle(itemID: item.id, to: language ?? Self.translationTargetLanguage(for: item))
    }

    public func translateArticle(itemID: String, to language: String? = nil) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }

        aiPanelOpen = true
        aiTab = .translate
        translationError = nil

        let aiService = currentAIService
        guard aiService.isConfigured else {
            translationError = AIError.notConfigured.localizedDescription
            aiSettingsSheetOpen = true
            showToast(AIError.notConfigured.localizedDescription)
            return
        }

        translationTask?.cancel()
        isTranslatingArticle = true
        let targetLanguage = language ?? Self.translationTargetLanguage(for: item)

        translationTask = Task { [weak self, aiService] in
            do {
                let translations = try await aiService.translate(item, to: targetLanguage)
                await MainActor.run {
                    guard let self else { return }
                    if let updated = self.updateItem(itemID, mutate: { item in
                        for blockIndex in item.body.indices {
                            let blockID = item.body[blockIndex].id.uuidString
                            if let translation = translations[blockID]?.trimmingCharacters(in: .whitespacesAndNewlines), !translation.isEmpty {
                                item.body[blockIndex].translation = translation
                            }
                        }
                    }) {
                        self.persist { repository in
                            try await repository.saveItem(updated)
                        }
                    }
                    self.isTranslatingArticle = false
                    self.bilingual = true
                    self.showToast("译文已保存到本地")
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isTranslatingArticle = false
                }
            } catch {
                await MainActor.run {
                    let message = Self.userFacingAIMessage(error)
                    self?.translationError = message
                    self?.isTranslatingArticle = false
                    self?.showToast(message)
                }
            }
        }
    }

    private func translateSelectionNow(_ text: String) {
        selectionTranslationTask?.cancel()
        isTranslatingSelection = true

        let block = ContentBlock(kind: .paragraph, language: selectedItem?.language ?? "auto", text: text)
        let item = ReaderItem(
            id: "selection-\(block.id.uuidString)",
            type: "selection",
            kind: selectedItem?.kind ?? .web,
            source: selectedItem?.source ?? "选区",
            author: selectedItem?.author ?? "",
            title: selectedItem?.title ?? "选区翻译",
            excerpt: text,
            publishedAt: Date(),
            language: selectedItem?.language ?? "auto",
            tagIDs: [],
            folderID: "",
            isFavorite: false,
            isUnread: false,
            progress: 0,
            hue: selectedItem?.hue ?? 0,
            hasCover: false,
            body: [block],
            summary: ReaderSummary(text: [], keys: [], tagSuggestions: [])
        )
        let targetLanguage = Self.translationTargetLanguage(for: item)

        let aiService = currentAIService
        selectionTranslationTask = Task { [weak self, aiService] in
            do {
                let translations = try await aiService.translate(item, to: targetLanguage)
                await MainActor.run {
                    self?.pendingTranslationResult = translations[block.id.uuidString]
                    self?.isTranslatingSelection = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isTranslatingSelection = false
                }
            } catch {
                await MainActor.run {
                    let message = Self.userFacingAIMessage(error)
                    self?.translationError = message
                    self?.isTranslatingSelection = false
                    self?.showToast(message)
                }
            }
        }
    }

    private func appendChatToken(_ token: String, to messageID: UUID) {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageID }) else { return }
        chatMessages[index].text += token
    }

    private func removeEmptyAssistantMessage(id: UUID) {
        guard let index = chatMessages.firstIndex(where: { $0.id == id }) else { return }
        if chatMessages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chatMessages.remove(at: index)
        }
    }

    public func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled {
                toastMessage = nil
            }
        }
    }

    public func generateRemix(type: String, selectedSourceIDs: Set<String>) {
        let selectedItems = items.filter { selectedSourceIDs.contains($0.id) }
        let fallbackItems = selectedItem.map { [$0] } ?? []
        let sourceItems = selectedItems.isEmpty ? fallbackItems : selectedItems
        guard !sourceItems.isEmpty else { return }

        aiPanelOpen = true
        aiTab = .remix
        remixOutput = ""
        remixError = nil

        let aiService = currentAIService
        guard aiService.isConfigured else {
            remixError = AIError.notConfigured.localizedDescription
            aiSettingsSheetOpen = true
            showToast(AIError.notConfigured.localizedDescription)
            return
        }

        remixTask?.cancel()
        isGeneratingRemix = true
        remixTask = Task { [weak self, aiService] in
            do {
                for try await token in aiService.remix(type: type, items: sourceItems) {
                    await MainActor.run {
                        self?.remixOutput += token
                    }
                }
                await MainActor.run {
                    self?.isGeneratingRemix = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isGeneratingRemix = false
                }
            } catch {
                await MainActor.run {
                    let message = Self.userFacingAIMessage(error)
                    self?.remixError = message
                    self?.isGeneratingRemix = false
                    self?.showToast(message)
                }
            }
        }
    }

    public func inView(_ item: ReaderItem, _ viewID: String) -> Bool {
        switch viewID {
        case "all":
            return true
        case "inbox":
            return item.isUnread || (item.progress > 0 && item.progress < 1)
        case "unread":
            return item.isUnread
        case "fav":
            return item.isFavorite
        case "later":
            return item.progress > 0 && item.progress < 1
        case "archive":
            return false
        default:
            if let platform = platforms.first(where: { $0.id == viewID }) {
                let feedIDs = Set(platform.feeds.map(\.id))
                return item.feedID.map { feedIDs.contains($0) } ?? false
            }
            if viewID.hasPrefix("f-") {
                return item.feedID == viewID
            }
            if viewID.hasPrefix("fo-") {
                return folderIDs(includingChildrenOf: viewID).contains(item.folderID)
            }
            if viewID.hasPrefix("t-") {
                return item.tagIDs.contains(viewID)
            }
            return true
        }
    }

    private var allFolders: [ReaderFolder] {
        folders.flatMap { folder in [folder] + folder.children }
    }

    private func searchText(for item: ReaderItem) -> String {
        let tagNames = item.tagIDs.compactMap { name(for: $0) }.joined(separator: " ")
        return [item.title, item.excerpt, item.source, item.author, item.url ?? "", tagNames].joined(separator: " ")
    }

    private func folderIDs(includingChildrenOf id: String) -> Set<String> {
        guard let folder = allFolders.first(where: { $0.id == id }) else { return [id] }
        return Set([folder.id] + folder.children.map(\.id))
    }

    @discardableResult
    private func updateItem(_ id: String, mutate: (inout ReaderItem) -> Void) -> ReaderItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        mutate(&items[index])
        return items[index]
    }

    private func selectVisibleItem(offset: Int) -> Bool {
        let visible = visibleItems
        guard !visible.isEmpty else {
            selectedItemID = nil
            return false
        }

        let targetIndex: Int
        if let selectedItemID, let currentIndex = visible.firstIndex(where: { $0.id == selectedItemID }) {
            targetIndex = currentIndex + offset
        } else {
            targetIndex = offset >= 0 ? 0 : visible.count - 1
        }

        guard visible.indices.contains(targetIndex) else { return false }
        selectItem(visible[targetIndex].id)
        return true
    }

    private func resetSelectionTransientState() {
        pendingTranslationText = nil
        pendingTranslationResult = nil
        translationError = nil
        chatTask?.cancel()
        remixTask?.cancel()
        isSendingMessage = false
        isGeneratingRemix = false
        chatError = nil
        remixError = nil
    }

    private func closeTransientOverlaysForOnboarding() {
        commandPaletteOpen = false
        addModalOpen = false
        subscriptionsOpen = false
        aiSettingsSheetOpen = false
        typographyOpen = false
        pendingDeleteItemID = nil
    }

    private func prepareForOnboardingStep() {
        if onboardingStep == .aiSettings {
            aiPanelOpen = true
            aiTab = .summary
        }
    }

    private func apply(_ snapshot: LibrarySnapshot) {
        items = snapshot.items
        tags = snapshot.tags
        platforms = snapshot.platforms
        folders = snapshot.folders
        readingOffsets = snapshot.readingOffsets

        if let selectedItemID, items.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = visibleItems.first?.id ?? items.first?.id
    }

    private func syncFeedsNow(showToastOnCompletion: Bool) async {
        guard !isSyncingFeeds else { return }
        let feeds = platforms
            .first { $0.id == "p-rss" }?
            .feeds
            .filter { $0.url?.isEmpty == false } ?? []
        guard !feeds.isEmpty else { return }

        isSyncingFeeds = true
        let summary = await feedSyncService.syncAll(feeds: feeds)
        do {
            try await loadLibraryFromRepository()
        } catch {
            showToast("加载本地资料库失败")
        }
        applyFeedSyncSummary(summary)
        isSyncingFeeds = false

        guard showToastOnCompletion else { return }
        if summary.failureCount > 0 {
            showToast("同步完成,\(summary.failureCount) 个订阅失败")
        } else if summary.insertedCount > 0 {
            showToast("已同步 \(summary.insertedCount) 篇新条目")
        } else {
            showToast("订阅已是最新")
        }
    }

    private func applyFeedSyncSummary(_ summary: FeedSyncSummary) {
        var errors = feedSyncErrors
        for result in summary.results {
            if let message = result.errorMessage {
                errors[result.feedID] = message
            } else {
                errors[result.feedID] = nil
            }
        }
        feedSyncErrors = errors
    }

    private func scheduleAutomaticFeedSyncIfNeeded() {
        guard !isSyncingFeeds else { return }
        let fetchedDates = platforms.flatMap(\.feeds).compactMap { feed -> Date? in
            guard feed.url?.isEmpty == false else { return nil }
            return feed.lastFetchedAt
        }
        let hasSyncableFeed = platforms.flatMap(\.feeds).contains { $0.url?.isEmpty == false }
        guard hasSyncableFeed else { return }

        if fetchedDates.isEmpty || fetchedDates.min().map({ Date().timeIntervalSince($0) > 3600 }) == true {
            Task {
                await syncFeedsNow(showToastOnCompletion: false)
            }
        }
    }

    private func startFeedSyncTimer() {
        feedSyncTimerTask?.cancel()
        feedSyncTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_600_000_000_000)
                await self?.syncFeedsNow(showToastOnCompletion: false)
            }
        }
    }

    private func persist(
        onErrorMessage: String = "保存本地资料库失败",
        _ operation: @escaping @Sendable (any ReaderRepository) async throws -> Void
    ) {
        let repository = repository
        let task = Task { [weak self] in
            do {
                try await operation(repository)
            } catch {
                await MainActor.run {
                    self?.showToast(onErrorMessage)
                }
            }
        }
        persistenceTasks.append(task)
    }

    private func scheduleReadingStateSave(for id: String) {
        readingStateSaveTasks[id]?.cancel()
        readingStateSaveTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.readingStateSaveTasks[id] = nil
                self?.saveReadingStateNow(for: id)
            }
        }
    }

    private func saveReadingStateNow(for id: String) {
        let progress = items.first { $0.id == id }?.progress ?? 0
        let offset = readingOffsets[id] ?? 0
        persist { repository in
            try await repository.saveReadingState(itemID: id, progress: progress, offset: offset)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResultIDs = nil
            return
        }

        searchTask = Task { [weak self, repository] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            do {
                let ids = try await repository.search(trimmed)
                await MainActor.run {
                    guard self?.query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    self?.searchResultIDs = Set(ids)
                }
            } catch {
                await MainActor.run {
                    guard self?.query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    self?.searchResultIDs = nil
                }
            }
        }
    }

    private static func domain(from url: String) -> String {
        let candidate = url.hasPrefix("http") ? url : "https://\(url)"
        guard
            let host = URL(string: candidate)?.host?.replacingOccurrences(of: "www.", with: ""),
            !host.isEmpty
        else {
            return url.isEmpty ? "网页" : url
        }
        return host
    }

    private static func themeMode(from userDefaults: UserDefaults) -> ReaderThemeMode {
        guard
            let rawValue = userDefaults.string(forKey: PreferenceKey.themeMode),
            let mode = ReaderThemeMode(rawValue: rawValue)
        else {
            return .light
        }
        return mode
    }

    private static func doublePreference(forKey key: String, defaultValue: Double, userDefaults: UserDefaults) -> Double {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return userDefaults.double(forKey: key)
    }

    private static func translationTargetLanguage(for item: ReaderItem) -> String {
        item.language.lowercased().hasPrefix("en") ? "zh" : "en"
    }

    private static func userFacingAIMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return "AI 请求失败"
    }
}

private enum PreferenceKey {
    static let themeMode = "ReaderStore.themeMode"
    static let useSerif = "ReaderStore.useSerif"
    static let fontSize = "ReaderStore.fontSize"
    static let lineHeight = "ReaderStore.lineHeight"
    static let readingWidth = "ReaderStore.readingWidth"
    static let bilingual = "ReaderStore.bilingual"
    static let onboardingCompleted = "ReaderStore.onboardingCompleted"
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
