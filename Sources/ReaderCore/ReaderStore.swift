import Combine
import Foundation

@MainActor
public final class ReaderStore: ObservableObject {
    @Published public var items: [ReaderItem]
    @Published public var activeViewID: String
    @Published public var selectedItemID: String?
    @Published public var query: String
    @Published public var sortMode: SortMode
    @Published public var themeMode: ReaderThemeMode
    @Published public var aiPanelOpen: Bool
    @Published public var aiTab: AITab
    @Published public var chatMessages: [ChatMessage]
    @Published public var isSendingMessage: Bool
    @Published public var useSerif: Bool
    @Published public var fontSize: Double
    @Published public var lineHeight: Double
    @Published public var readingWidth: Double
    @Published public var bilingual: Bool
    @Published public var typographyOpen: Bool
    @Published public var commandPaletteOpen: Bool
    @Published public var addModalOpen: Bool
    @Published public var subscriptionsOpen: Bool
    @Published public var toastMessage: String?
    @Published public var pendingTranslationText: String?

    public let smartViews = SampleLibrary.smartViews
    public let tags = SampleLibrary.tags
    public let platforms = SampleLibrary.platforms
    public let folders = SampleLibrary.folders
    public let chatSuggestions = SampleLibrary.chatSuggestions

    private var toastTask: Task<Void, Never>?
    private var readingOffsets: [String: Double]

    public init(
        items: [ReaderItem] = SampleLibrary.items,
        activeViewID: String = "inbox",
        selectedItemID: String? = "a1"
    ) {
        self.items = items
        self.activeViewID = activeViewID
        self.selectedItemID = selectedItemID
        self.query = ""
        self.sortMode = .newest
        self.themeMode = .light
        self.aiPanelOpen = true
        self.aiTab = .summary
        self.chatMessages = SampleLibrary.seedChat
        self.isSendingMessage = false
        self.useSerif = true
        self.fontSize = 18
        self.lineHeight = 1.78
        self.readingWidth = 680
        self.bilingual = true
        self.typographyOpen = false
        self.commandPaletteOpen = false
        self.addModalOpen = false
        self.subscriptionsOpen = false
        self.toastMessage = nil
        self.pendingTranslationText = nil
        self.readingOffsets = [:]
    }

    public var selectedItem: ReaderItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    public var visibleItems: [ReaderItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = items.filter { item in
            inView(item, activeViewID)
        }

        if !trimmedQuery.isEmpty {
            result = result.filter { item in
                searchText(for: item).lowercased().contains(trimmedQuery)
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
            pendingTranslationText = nil
        }
        selectedItemID = id
        updateItem(id) { item in
            item.isUnread = false
        }
    }

    public func toggleFavorite(_ id: String) {
        updateItem(id) { item in
            item.isFavorite.toggle()
        }
    }

    public func setProgress(_ id: String, progress: Double) {
        updateItem(id) { item in
            item.progress = min(max(progress, 0), 1)
        }
    }

    public func setReadingOffset(_ id: String, offset: Double) {
        readingOffsets[id] = max(0, offset)
    }

    public func readingOffset(for id: String) -> Double {
        readingOffsets[id] ?? 0
    }

    public func markAllRead() {
        for index in items.indices {
            items[index].isUnread = false
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
        updateItem(itemID) { item in
            item.highlights.removeAll { $0.quote == trimmed }
            item.highlights.append(Highlight(quote: trimmed, note: note))
        }
        showToast(note.isEmpty ? "已高亮" : "已保存高亮 + 笔记")
    }

    public func addItem(from draft: AddContentDraft) {
        let normalizedURL = draft.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = Self.domain(from: normalizedURL)
        let id = UUID().uuidString
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hue = Double(180 + ((normalizedURL.count + title.count) % 160))
        let publishedAt = Date()
        let baseSummary = ReaderSummary(
            text: ["这是你刚刚保存的内容,AI 可以为它生成摘要。"],
            keys: ["来源已保存到本地", "可打标签与归类", "支持翻译与二次创作"],
            tagSuggestions: ["新收藏"]
        )
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
                summary: baseSummary
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
                summary: baseSummary
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
                summary: baseSummary
            )
        }

        items.insert(item, at: 0)
        addModalOpen = false
        activeViewID = "inbox"
        selectedItemID = item.id
        showToast("已保存到本地 · \(item.source)")
    }

    public func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        aiPanelOpen = true
        aiTab = .chat
        chatMessages.append(ChatMessage(role: .user, text: trimmed))
        isSendingMessage = true

        let item = selectedItem ?? items.first
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            if let item {
                chatMessages.append(generateReply(to: trimmed, item: item))
            }
            isSendingMessage = false
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
        aiPanelOpen = true
        aiTab = .translate
        showToast("已打开翻译并载入选区")
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

    public func generatedRemix(type: String, selectedSourceIDs: Set<String>) -> String {
        guard let item = selectedItem else { return "" }
        let sourceItems = items.filter { selectedSourceIDs.contains($0.id) }
        let keys = item.summary.keys
        let titles = sourceItems.map(\.title)

        switch type {
        case "rx-thread":
            return [
                "1/ \(item.title) —— 一篇值得记下来的文章。",
                "2/ \(keys[safe: 0] ?? "")",
                "3/ \(keys[safe: 1] ?? "")",
                "4/ \(keys[safe: 2] ?? "")",
                "5/ 完整笔记已存进我的本地 Reader,数据全在自己手里。"
            ].filter { !$0.hasSuffix(" ") }.joined(separator: "\n\n")
        case "rx-weekly":
            return "## 本周阅读回顾\n\n本周共读 \(sourceItems.count) 篇:\n" +
                titles.map { "- \($0)" }.joined(separator: "\n") +
                "\n\n一句话收获:\(keys.first ?? "持续把好内容沉淀到本地。")"
        case "rx-cross":
            return "## 综述:关于「本地优先」的几篇对读\n\n综合 \(titles.count) 篇来源,可以看到一条共同线索:\n\n" +
                titles.enumerated().map { "\($0.offset + 1). 《\($0.element)》" }.joined(separator: "\n") +
                "\n\n它们都指向同一个判断:\(keys.first ?? "把数据的所有权还给用户")。"
        default:
            let highlightText = item.highlights.isEmpty ? "" : "\n\n## 我的高亮\n" + item.highlights.map {
                "> \($0.quote)" + ($0.note.isEmpty ? "" : "\n  注:\($0.note)")
            }.joined(separator: "\n")
            return "# \(item.title) · 读书笔记\n\n## 要点\n" + keys.map { "- \($0)" }.joined(separator: "\n") + highlightText
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
        return [item.title, item.excerpt, item.source, item.author, tagNames].joined(separator: " ")
    }

    private func folderIDs(includingChildrenOf id: String) -> Set<String> {
        guard let folder = allFolders.first(where: { $0.id == id }) else { return [id] }
        return Set([folder.id] + folder.children.map(\.id))
    }

    private func updateItem(_ id: String, mutate: (inout ReaderItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }

    private func generateReply(to text: String, item: ReaderItem) -> ChatMessage {
        let keys = item.summary.keys
        let lowercased = text.lowercased()

        if text.range(of: #"总结|摘要|三句|概括|要点"#, options: .regularExpression) != nil {
            return ChatMessage(
                role: .assistant,
                text: item.summary.text.first.map { "\($0)\n\n核心要点:\(keys.joined(separator: ";"))" } ?? item.excerpt,
                citations: [item.source]
            )
        }

        if text.contains("翻译") {
            return ChatMessage(
                role: .assistant,
                text: "已为你处理这段翻译。大意是围绕「\(item.summary.tagSuggestions.first ?? "核心议题")」展开。\n\n提示:点开阅读区顶部的「双语对照」,可以逐段对照原文与译文。",
                citations: [item.source]
            )
        }

        if text.range(of: #"微博|推文|thread|改写|创作|整理成"#, options: .regularExpression) != nil {
            return ChatMessage(
                role: .assistant,
                text: "草拟了一条:\n\n\(item.title) —— \(keys.first ?? "")\n\n要更口语、更短,还是配上我的高亮?可以到「二创」标签里换个模板。",
                citations: [item.source]
            )
        }

        if lowercased.contains("crdt") {
            return ChatMessage(
                role: .assistant,
                text: "CRDT(无冲突复制数据类型)是一类数据结构:多个副本各自离线修改后,合并时能自动收敛到一致结果、无需中央服务器裁决。这正是「本地优先」实现实时协作的关键技术。",
                citations: [item.source]
            )
        }

        if text.range(of: #"异同|对比|交叉|其他"#, options: .regularExpression) != nil {
            return ChatMessage(
                role: .assistant,
                text: "在你收藏夹里和「本地优先」相关的几篇中:\n\n· 这篇强调数据所有权与长期可用;\n· @rauchg 那条更看重架构钟摆;\n· 阮一峰周刊则落在端侧推理。\n\n共同结论:把数据留在本地,同时不放弃协作。",
                citations: ["本地优先", "@rauchg", "科技爱好者周刊"]
            )
        }

        return ChatMessage(
            role: .assistant,
            text: "围绕《\(item.title)》,我的理解是:\(keys.first ?? item.excerpt)。\n\n需要我做一句话摘要、翻译,还是改写成读书笔记?",
            citations: [item.source]
        )
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
