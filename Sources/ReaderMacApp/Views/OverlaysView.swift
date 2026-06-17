import AppKit
import ReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct CommandPaletteView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    @State private var query = ""

    private var commands: [PaletteCommand] {
        [
            PaletteCommand(id: "add", title: "添加内容", subtitle: "网址 / 附件 / Markdown", icon: "plus", shortcut: "⌘N", keywords: "add url 采集 收藏") {
                store.commandPaletteOpen = false
                store.addModalOpen = true
            },
            PaletteCommand(id: "theme", title: "切换 亮 / 暗 外观", subtitle: nil, icon: store.themeMode == .dark ? "sun" : "moon", shortcut: nil, keywords: "theme dark light 主题") {
                store.themeMode = store.themeMode == .dark ? .light : .dark
                store.commandPaletteOpen = false
            },
            PaletteCommand(id: "ai", title: "打开 AI 助手", subtitle: nil, icon: "sparkles", shortcut: nil, keywords: "ai 助手 chat") {
                store.aiPanelOpen = true
                store.commandPaletteOpen = false
            },
            PaletteCommand(id: "bilingual", title: "切换 双语对照", subtitle: nil, icon: "translate", shortcut: nil, keywords: "翻译 双语 translate") {
                store.bilingual.toggle()
                store.commandPaletteOpen = false
            },
            PaletteCommand(id: "serif", title: "切换 衬线阅读模式", subtitle: nil, icon: "doc", shortcut: nil, keywords: "字体 衬线 serif") {
                store.useSerif.toggle()
                store.commandPaletteOpen = false
            },
            PaletteCommand(id: "subs", title: "管理订阅源", subtitle: nil, icon: "rss", shortcut: nil, keywords: "rss 订阅 subscribe") {
                store.commandPaletteOpen = false
                store.subscriptionsOpen = true
            },
            PaletteCommand(id: "onboarding", title: "新手引导", subtitle: "重新熟悉核心入口", icon: "help", shortcut: nil, keywords: "help guide onboarding 教程 引导") {
                store.commandPaletteOpen = false
                store.openOnboarding()
            },
            PaletteCommand(id: "readall", title: "全部标为已读", subtitle: nil, icon: "check", shortcut: nil, keywords: "已读 read") {
                store.markAllRead()
                store.commandPaletteOpen = false
            },
            PaletteCommand(id: "fav", title: "收藏 / 取消收藏当前", subtitle: nil, icon: "star", shortcut: nil, keywords: "收藏 star") {
                if let item = store.selectedItem {
                    store.toggleFavorite(item.id)
                }
                store.commandPaletteOpen = false
            }
        ]
    }

    private var filteredCommands: [PaletteCommand] {
        let q = query.lowercased()
        guard !q.isEmpty else { return commands }
        return commands.filter { command in
            command.title.lowercased().contains(q) || command.keywords.lowercased().contains(q)
        }
    }

    private var filteredItems: [ReaderItem] {
        let q = query.lowercased()
        let candidates = q.isEmpty ? Array(store.items.prefix(5)) : store.items.filter { item in
            [item.title, item.source, item.excerpt].joined(separator: " ").lowercased().contains(q)
        }
        return Array(candidates.prefix(7))
    }

    var body: some View {
        Scrim(alignment: .top, topPadding: 88) {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Icon(name: "search", size: 18)
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                    TextField("搜索内容,或输入命令…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .focused($focused)
                        .onSubmit {
                            runFirstResult()
                        }
                    Keycap("esc")
                }
                .padding(.horizontal, 18)
                .frame(height: 58)

                Hairline()

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !filteredCommands.isEmpty {
                            PaletteGroupLabel("命令")
                            ForEach(filteredCommands) { command in
                                PaletteCommandRow(command: command)
                            }
                        }

                        if !filteredItems.isEmpty {
                            PaletteGroupLabel("内容")
                            ForEach(filteredItems) { item in
                                PaletteItemRow(item: item)
                            }
                        }

                        if filteredCommands.isEmpty && filteredItems.isEmpty {
                            EmptyState(icon: "search", title: "没有匹配项")
                                .frame(height: 220)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 380)

                Hairline()

                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Keycap("↑")
                        Keycap("↓")
                        Text("选择")
                    }
                    HStack(spacing: 5) {
                        Keycap("↵")
                        Text("打开")
                    }
                    HStack(spacing: 5) {
                        Keycap("⌘")
                        Keycap("K")
                        Text("唤起")
                    }
                    Spacer()
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                .padding(.horizontal, 16)
                .frame(height: 38)
            }
            .frame(width: 620)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.30), radius: 34, y: 16)
            .onAppear {
                focused = true
            }
            .onExitCommand {
                store.commandPaletteOpen = false
            }
        } onDismiss: {
            store.commandPaletteOpen = false
        }
    }

    private func runFirstResult() {
        if let command = filteredCommands.first {
            command.action()
        } else if let item = filteredItems.first {
            store.selectItem(item.id)
            store.commandPaletteOpen = false
        }
    }
}

struct AddContentModal: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    @State private var mode = "url"
    @State private var url = ""
    @State private var fetched = false
    @State private var isFetchingURL = false
    @State private var isSaving = false
    @State private var isImportingAttachment = false
    @State private var capturedArticle: CapturedArticle?
    @State private var title = ""
    @State private var markdown = ""
    @State private var selectedTags: Set<String> = []
    @State private var folderID = "fo-product"

    private let tabs = [
        ("url", "网址", "link"),
        ("file", "附件", "paperclip"),
        ("md", "Markdown", "markdown"),
        ("other", "其他", "ellipsis")
    ]

    var body: some View {
        Scrim(alignment: .center) {
            VStack(spacing: 0) {
                ModalHeader(icon: "plus", title: "添加内容") {
                    store.addModalOpen = false
                }

                HStack(spacing: 3) {
                    ForEach(tabs, id: \.0) { tab in
                        Button {
                            mode = tab.0
                        } label: {
                            HStack(spacing: 7) {
                                Icon(name: tab.2, size: 14)
                                Text(tab.1)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(mode == tab.0 ? ReaderStyle.accent : ReaderStyle.secondaryText(scheme))
                            .padding(.horizontal, 13)
                            .frame(height: 36)
                            .overlay(alignment: .bottom) {
                                if mode == tab.0 {
                                    Capsule()
                                        .fill(ReaderStyle.accent)
                                        .frame(height: 2)
                                        .padding(.horizontal, 10)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        modalBody

                        if mode != "other", mode != "file" {
                            taxonomyFields
                        }
                    }
                    .padding(18)
                }
                .frame(minHeight: 280, maxHeight: 520)

                Hairline()

                HStack(spacing: 10) {
                    Spacer()
                    TextIconButton(title: "取消", icon: "close") {
                        store.addModalOpen = false
                    }
                    TextIconButton(title: "保存到本地", icon: "check", role: .primary) {
                        save()
                    }
                    .disabled(isSaving || isImportingAttachment)
                }
                .padding(16)
            }
            .frame(width: 600)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.30), radius: 34, y: 16)
        } onDismiss: {
            store.addModalOpen = false
        }
    }

    @ViewBuilder
    private var modalBody: some View {
        switch mode {
        case "url":
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(title: "网址") {
                    HStack(spacing: 9) {
                        Icon(name: "link", size: 15)
                            .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                        TextField("粘贴文章 / 视频 / 推文链接…", text: $url)
                            .textFieldStyle(.plain)
                            .onChange(of: url) { _ in
                                fetched = false
                                capturedArticle = nil
                            }
                        Button(isFetchingURL ? "抓取中" : "抓取") {
                            Task {
                                await fetchURLPreview()
                            }
                        }
                        .disabled(isFetchingURL || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFetchingURL ? ReaderStyle.tertiaryText(scheme) : ReaderStyle.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(ReaderStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                if let capturedArticle {
                    HStack(spacing: 13) {
                        CoverArtwork(coverPath: capturedArticle.coverPath, hue: capturedArticle.hue, cornerRadius: 8)
                            .frame(width: 96, height: 72)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(capturedArticle.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ReaderStyle.text(scheme))
                                .lineLimit(2)
                            Text("\(capturedArticle.source) · 自动提取 · 约 \(capturedArticle.readingTime) 分钟")
                                .font(.system(size: 12))
                                .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                            Text(capturedArticle.excerpt)
                                .font(.system(size: 12.5))
                                .lineLimit(2)
                                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                        }
                    }
                    .padding(13)
                    .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                } else if fetched {
                    Text("未能提取正文")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                }
            }
        case "file":
            VStack(spacing: 10) {
                Icon(name: "paperclip", size: 40)
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                Text(isImportingAttachment ? "正在导入附件" : "拖入 PDF、视频或图片")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReaderStyle.secondaryText(scheme))
                Text("或点击从本地选择 · 文件将保存在本地")
                    .font(.system(size: 12.5))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 38)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .onTapGesture {
                chooseAttachment()
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                importDroppedAttachment(providers)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(ReaderStyle.separator(scheme))
            }
        case "md":
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(title: "标题") {
                    TextField("给这篇笔记起个名字", text: $title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                LabeledField(title: "正文(Markdown)") {
                    TextField("# 标题\n\n支持 **加粗**、*斜体*、> 引用、- 列表…", text: $markdown, axis: .vertical)
                        .lineLimit(7...12)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(12)
                        .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        default:
            VStack(spacing: 10) {
                OtherAddOption(icon: "copy", title: "从剪贴板粘贴", description: "自动识别链接或纯文本")
                OtherAddOption(icon: "rss", title: "邮件转发收件地址", description: "把 Newsletter 转发到 inbox@local")
                OtherAddOption(icon: "globe", title: "浏览器扩展", description: "在任意网页一键保存到本地")
            }
        }
    }

    private var taxonomyFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledField(title: "标签") {
                FlowWrap(spacing: 7) {
                    ForEach(store.tags) { tag in
                        Chip(
                            title: tag.name,
                            color: Color(hex: tag.colorHex),
                            selected: selectedTags.contains(tag.id)
                        ) {
                            toggleTag(tag.id)
                        }
                    }
                }
            }

            LabeledField(title: "目录") {
                FlowWrap(spacing: 7) {
                    ForEach(flatFolders) { folder in
                        Chip(
                            title: folder.name,
                            selected: folderID == folder.id,
                            icon: "folder"
                        ) {
                            folderID = folder.id
                        }
                    }
                }
            }
        }
    }

    private var flatFolders: [ReaderFolder] {
        store.folders.flatMap { folder in
            folder.children.isEmpty ? [folder] : folder.children
        }
    }

    private var domain: String {
        let candidate = url.hasPrefix("http") ? url : "https://\(url)"
        guard let host = URL(string: candidate)?.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty else {
            return url.isEmpty ? "网页" : url
        }
        return host
    }

    private func toggleTag(_ id: String) {
        if selectedTags.contains(id) {
            selectedTags.remove(id)
        } else {
            selectedTags.insert(id)
        }
    }

    private func save() {
        if mode == "url" {
            guard let capturedArticle else {
                store.showToast("请先抓取网址")
                return
            }

            isSaving = true
            Task {
                do {
                    try await store.saveCapturedArticle(
                        capturedArticle,
                        tagIDs: Array(selectedTags),
                        folderID: folderID
                    )
                } catch {
                    store.showToast(error.localizedDescription)
                }
                isSaving = false
            }
            return
        }

        if mode == "file" {
            chooseAttachment()
            return
        }

        store.addItem(
            from: AddContentDraft(
                mode: mode,
                url: url,
                title: title,
                markdown: markdown,
                tagIDs: Array(selectedTags),
                folderID: folderID
            )
        )
    }

    private func fetchURLPreview() async {
        isFetchingURL = true
        fetched = false
        capturedArticle = nil

        do {
            let article = try await store.captureURLPreview(url)
            capturedArticle = article
            title = article.title
            fetched = true
        } catch {
            store.showToast(error.localizedDescription)
            fetched = true
        }

        isFetchingURL = false
    }

    private func chooseAttachment() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .heic, .mpeg4Movie, .quickTimeMovie]
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        Task {
            await importAttachment(at: url)
        }
    }

    private func importDroppedAttachment(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in
                await importAttachment(at: url)
            }
        }
        return true
    }

    private func importAttachment(at url: URL) async {
        isImportingAttachment = true
        await store.importAttachment(
            at: url,
            tagIDs: Array(selectedTags),
            folderID: folderID
        )
        isImportingAttachment = false
    }
}

struct SubscriptionsModal: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    @FocusState private var feedURLFocused: Bool
    @State private var enabled: [String: Bool] = [:]
    @State private var newFeedURL = ""

    var body: some View {
        Scrim(alignment: .center) {
            VStack(spacing: 0) {
                ModalHeader(icon: "rss", title: "管理订阅源") {
                    store.subscriptionsOpen = false
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 9) {
                            Icon(name: "plus", size: 15)
                            TextField("添加 RSS 链接…", text: $newFeedURL)
                                .textFieldStyle(.plain)
                                .focused($feedURLFocused)
                            Button(store.isSyncingFeeds ? "同步中" : "订阅") {
                                Task {
                                    await store.addRSSFeed(newFeedURL)
                                    newFeedURL = ""
                                }
                            }
                            .disabled(store.isSyncingFeeds || newFeedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ReaderStyle.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(ReaderStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        ForEach(store.platforms) { platform in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Icon(name: platform.icon, size: 14)
                                    Text(platform.name)
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ReaderStyle.tertiaryText(scheme))

                                ForEach(platform.feeds) { feed in
                                    SubscriptionRow(
                                        feed: feed,
                                        failureMessage: store.feedSyncErrors[feed.id],
                                        isOn: binding(for: feed.id)
                                    )
                                }
                            }
                        }
                    }
                    .padding(18)
                }

                Hairline()

                HStack {
                    Text("所有订阅内容都会下载并保存到本地")
                        .font(.system(size: 12))
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                    Spacer()
                    TextIconButton(
                        title: store.isSyncingFeeds ? "同步中" : "刷新",
                        icon: "rss"
                    ) {
                        store.syncFeeds()
                    }
                    .disabled(store.isSyncingFeeds)
                    TextIconButton(title: "完成", icon: "check", role: .primary) {
                        store.subscriptionsOpen = false
                    }
                }
                .padding(16)
            }
            .frame(width: 680, height: 620)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.30), radius: 34, y: 16)
            .onAppear {
                if enabled.isEmpty {
                    enabled = Dictionary(uniqueKeysWithValues: store.platforms.flatMap(\.feeds).map { ($0.id, true) })
                }
                feedURLFocused = true
            }
        } onDismiss: {
            store.subscriptionsOpen = false
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabled[id, default: true] },
            set: { enabled[id] = $0 }
        )
    }
}

private struct SubscriptionRow: View {
    let feed: Feed
    var failureMessage: String?
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            Avatar(text: feed.monogram, color: Color(hex: feed.colorHex), size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ReaderStyle.text(scheme))
                Text(failureMessage.map { "上次同步失败 · \($0)" } ?? "每小时检查 · \(feed.count) 条未读")
                    .font(.system(size: 12))
                    .foregroundStyle(failureMessage == nil ? ReaderStyle.tertiaryText(scheme) : Color(hex: "#D8443A"))
            }

            Spacer()

            Text(isOn ? "已开启" : "已暂停")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(width: 48)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Hairline()
        }
    }
}

private struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let shortcut: String?
    let keywords: String
    let action: () -> Void
}

private struct PaletteCommandRow: View {
    let command: PaletteCommand
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: command.action) {
            HStack(spacing: 12) {
                Icon(name: command.icon, size: 17)
                    .foregroundStyle(ReaderStyle.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(command.title)
                        .font(.system(size: 14, weight: .medium))
                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                    }
                }

                Spacer()

                if let shortcut = command.shortcut {
                    Keycap(shortcut)
                }
            }
            .foregroundStyle(ReaderStyle.text(scheme))
            .padding(.horizontal, 11)
            .frame(height: 42)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PaletteItemRow: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    let item: ReaderItem

    var body: some View {
        Button {
            store.selectItem(item.id)
            store.commandPaletteOpen = false
        } label: {
            HStack(spacing: 12) {
                Icon(name: iconName(for: item.kind), size: 17)
                    .foregroundStyle(ReaderStyle.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text("\(item.source) · \(item.duration ?? "\(item.readingTime ?? 1) 分钟")")
                        .font(.system(size: 12))
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                        .lineLimit(1)
                }
                Spacer()
            }
            .foregroundStyle(ReaderStyle.text(scheme))
            .padding(.horizontal, 11)
            .frame(height: 42)
        }
        .buttonStyle(.plain)
    }
}

private struct PaletteGroupLabel: View {
    let title: String
    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 3)
    }
}

private struct Keycap: View {
    let title: String
    @Environment(\.colorScheme) private var scheme

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 1)
            )
    }
}

private struct Scrim<Content: View>: View {
    var alignment: Alignment = .top
    var topPadding: CGFloat = 0
    @ViewBuilder let content: Content
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    init(
        alignment: Alignment = .top,
        topPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        onDismiss: @escaping () -> Void
    ) {
        self.alignment = alignment
        self.topPadding = topPadding
        self.content = content()
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack(alignment: alignment) {
            Rectangle()
                .fill(Color.black.opacity(scheme == .dark ? 0.38 : 0.18))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            content
                .padding(.top, topPadding)
                .onTapGesture {}
        }
        .zIndex(80)
    }
}

private struct ModalHeader: View {
    let icon: String
    let title: String
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            Icon(name: icon, size: 17)
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Spacer()
            IconButton(icon: "close", title: "关闭", size: 26, iconSize: 15, action: onClose)
        }
        .foregroundStyle(ReaderStyle.text(scheme))
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Hairline()
        }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
            content
        }
    }
}

private struct OtherAddOption: View {
    let icon: String
    let title: String
    let description: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            Icon(name: icon, size: 17)
                .foregroundStyle(ReaderStyle.accent)
                .frame(width: 32, height: 32)
                .background(ReaderStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(ReaderStyle.text(scheme))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            }

            Spacer()
        }
        .padding(10)
        .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
