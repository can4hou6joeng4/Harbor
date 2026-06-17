import ReaderCore
import AppKit
import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Icon(name: "sparkles", size: 17)
                    .foregroundStyle(ReaderStyle.accent)
                Text("AI 助手")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ReaderStyle.text(scheme))
                Spacer()
                IconButton(icon: "panel-right", title: "收起", size: 26, iconSize: 15) {
                    store.aiPanelOpen = false
                }
            }
            .padding(.horizontal, 16)
            .frame(height: ReaderStyle.toolbarHeight)

            Hairline()

            HStack(spacing: 2) {
                ForEach(AITab.allCases) { tab in
                    Button {
                        store.aiTab = tab
                    } label: {
                        HStack(spacing: 5) {
                            Icon(name: icon(for: tab), size: 13)
                            Text(tab.title)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(store.aiTab == tab ? ReaderStyle.accent : ReaderStyle.secondaryText(scheme))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(store.aiTab == tab ? ReaderStyle.accent.opacity(0.16) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .onboardingTarget(.aiSettings)

            Hairline()

            if let item = store.selectedItem {
                switch store.aiTab {
                case .summary:
                    SummaryTab(item: item)
                case .translate:
                    TranslateTab(item: item)
                case .chat:
                    if store.isAIConfigured {
                        ChatTab(item: item)
                    } else {
                        ConnectAIState()
                    }
                case .remix:
                    if store.isAIConfigured {
                        RemixTab(item: item)
                    } else {
                        ConnectAIState()
                    }
                }
            } else {
                EmptyState(icon: "sparkles", title: "选择一篇内容后,AI 才能帮上忙")
            }
        }
        .background(.regularMaterial)
    }

    private func icon(for tab: AITab) -> String {
        switch tab {
        case .summary: "doc"
        case .translate: "translate"
        case .chat: "chat"
        case .remix: "wand"
        }
    }
}

private struct SummaryTab: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    let item: ReaderItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let hasSummary = item.summary.isStructured && !item.isSummaryOnly

                if !store.isAIConfigured && !hasSummary {
                    ConnectAIState()
                } else {
                    ContextPill(icon: iconName(for: item.kind), text: hasSummary ? "本地摘要" : "准备生成", strong: compact(item.title))

                    if hasSummary {
                        AIBlock(title: "一句话摘要", icon: "doc") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(item.summary.text.enumerated()), id: \.offset) { _, text in
                                    Text(text)
                                }
                            }
                            .font(.system(size: 13.5))
                            .lineSpacing(5)
                            .foregroundStyle(ReaderStyle.text(scheme))
                        }

                        AIBlock(title: "关键要点", icon: "list") {
                            VStack(alignment: .leading, spacing: 9) {
                                ForEach(Array(item.summary.keys.enumerated()), id: \.offset) { index, key in
                                    HStack(alignment: .top, spacing: 9) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(ReaderStyle.accent)
                                            .frame(width: 18, height: 18)
                                            .background(ReaderStyle.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        Text(key)
                                            .font(.system(size: 13))
                                            .lineSpacing(3)
                                    }
                                }
                            }
                        }

                        AIBlock(title: "建议标签", icon: "tag") {
                            FlowWrap(spacing: 6) {
                                ForEach(item.summary.tagSuggestions, id: \.self) { tag in
                                    Chip(title: tag, icon: "plus") {
                                        store.showToast("已添加标签「\(tag)」")
                                    }
                                }
                            }
                        }
                    } else {
                        AIBlock(title: "摘要", icon: "doc") {
                            Text("尚未生成摘要")
                                .font(.system(size: 13.5))
                                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    if let error = store.summaryGenerationError {
                        Text(error)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color(red: 0.82, green: 0.24, blue: 0.24))
                    }

                    HStack(spacing: 8) {
                        TextIconButton(
                            title: store.isGeneratingSummary ? "生成中" : (store.isAIConfigured ? (hasSummary ? "重新生成" : "生成摘要") : "连接 AI"),
                            icon: store.isAIConfigured ? "sparkles" : "link",
                            role: store.isAIConfigured ? .primary : .plain
                        ) {
                            if store.isAIConfigured {
                                store.generateSummary(for: item.id)
                            } else {
                                store.openAISettings()
                            }
                        }
                        .disabled(store.isGeneratingSummary)

                        if hasSummary {
                            TextIconButton(title: "复制", icon: "copy") {
                                copyToPasteboard((item.summary.text + item.summary.keys).joined(separator: "\n"))
                                store.showToast("摘要已复制")
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

private struct ConnectAIState: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 14) {
            Icon(name: "sparkles", size: 34)
                .foregroundStyle(ReaderStyle.accent)
            Text("连接 AI")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ReaderStyle.text(scheme))
            Text("使用前需要配置 \(credentialName)")
                .font(.system(size: 12.5))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                .multilineTextAlignment(.center)
            TextIconButton(title: "打开设置", icon: "gear", role: .primary) {
                store.openAISettings()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(18)
    }

    private var credentialName: String {
        if store.selectedAIProvider == .anthropic && store.anthropicAuthMode == .authToken {
            return "Anthropic Auth Token"
        }
        return "\(store.selectedAIProvider.displayName) API Key"
    }
}

private struct UpcomingAIState: View {
    let icon: String
    let title: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            Icon(name: icon, size: 32)
                .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

private struct TranslateTab: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    @State private var direction = "en2zh"

    let item: ReaderItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !store.isAIConfigured {
                    ConnectAIState()
                } else {
                    HStack {
                        Text("翻译方向")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ReaderStyle.secondaryText(scheme))
                        Spacer()
                        Picker("", selection: $direction) {
                            Text("英 → 中").tag("en2zh")
                            Text("中 → 英").tag("zh2en")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 128)
                    }
                    .padding(10)
                    .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    if let selectedText = store.pendingTranslationText {
                        AIBlock(title: "选区翻译", icon: "translate") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(selectedText)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineSpacing(4)
                                    .foregroundStyle(ReaderStyle.secondaryText(scheme))
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                if store.isTranslatingSelection {
                                    Text("选区翻译中")
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(ReaderStyle.secondaryText(scheme))
                                } else if let result = store.pendingTranslationResult, !result.isEmpty {
                                    Text(result)
                                        .font(.system(size: 13.5))
                                        .lineSpacing(5)
                                        .foregroundStyle(ReaderStyle.text(scheme))
                                } else {
                                    Text("尚未返回译文")
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(ReaderStyle.secondaryText(scheme))
                                }

                                TextIconButton(title: store.isTranslatingSelection ? "翻译中" : "重新翻译选区", icon: "translate") {
                                    store.translateSelection(selectedText)
                                }
                                .disabled(store.isTranslatingSelection)
                            }
                        }
                    }

                    AIBlock(title: "全文翻译", icon: "translate") {
                        VStack(alignment: .leading, spacing: 10) {
                            let translatedBlocks = item.body.filter { $0.kind != .image && !$0.translation.isEmpty }
                            if translatedBlocks.isEmpty {
                                Text("尚未翻译全文")
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(ReaderStyle.secondaryText(scheme))
                            } else {
                                ForEach(translatedBlocks.prefix(6)) { block in
                                    Text(block.translation)
                                        .font(.system(size: 13.5))
                                        .lineSpacing(5)
                                }
                            }
                        }
                        .foregroundStyle(ReaderStyle.text(scheme))
                    }

                    if let error = store.translationError {
                        Text(error)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color(red: 0.82, green: 0.24, blue: 0.24))
                    }

                    HStack(spacing: 8) {
                        TextIconButton(
                            title: store.isTranslatingArticle ? "翻译中" : (item.body.contains { !$0.translation.isEmpty } ? "重新翻译全文" : "翻译全文"),
                            icon: "translate",
                            role: .primary
                        ) {
                            store.translateArticle(itemID: item.id, to: targetLanguage)
                        }
                        .disabled(store.isTranslatingArticle)

                        TextIconButton(
                            title: store.bilingual ? "关闭双语对照" : "在阅读区开启双语对照",
                            icon: "eye",
                            role: store.bilingual ? .plain : .primary
                        ) {
                            store.bilingual.toggle()
                            store.showToast(store.bilingual ? "已在阅读区开启双语对照" : "已关闭双语对照")
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            direction = item.language == "en" ? "en2zh" : "zh2en"
        }
    }

    private var targetLanguage: String {
        direction == "en2zh" ? "zh" : "en"
    }
}

private struct ChatTab: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    @State private var input = ""

    let item: ReaderItem

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ContextPill(icon: "link", text: "已引用当前文章", strong: item.source)

                        ForEach(store.chatMessages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }

                        if store.isSendingMessage {
                            TypingRow()
                        }

                        if let error = store.chatError {
                            Text(error)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color(red: 0.82, green: 0.24, blue: 0.24))
                        }
                    }
                    .padding(16)
                }
                .onChange(of: store.chatMessages.count) { _ in
                    if let last = store.chatMessages.last {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            FlowWrap(spacing: 7) {
                ForEach(store.chatSuggestions, id: \.self) { suggestion in
                    Button {
                        store.sendMessage(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ReaderStyle.secondaryText(scheme))
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .background(ReaderStyle.controlFill(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Hairline()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("问点什么,或让 AI 处理这篇内容…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .padding(.vertical, 8)
                    .padding(.leading, 11)

                IconButton(icon: "send", title: "发送", size: 30, iconSize: 15, tint: Color.white) {
                    send()
                }
                .background(ReaderStyle.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSendingMessage)
                .padding(.trailing, 7)
                .padding(.bottom, 7)
            }
            .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
            }
            .padding(12)
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        store.sendMessage(text)
    }
}

private struct RemixTab: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    @State private var selectedType: String?
    @State private var selectedSources: Set<String> = []

    let item: ReaderItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AIBlock(title: "选择创作方式", icon: "wand") {
                    VStack(spacing: 2) {
                        ForEach(SampleLibrary.remixOptions, id: \.id) { option in
                            Button {
                                selectedType = option.id
                                if selectedSources.isEmpty {
                                    selectedSources = [item.id]
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Icon(name: option.icon, size: 17)
                                        .foregroundStyle(ReaderStyle.accent)
                                        .frame(width: 32, height: 32)
                                        .background(ReaderStyle.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(ReaderStyle.text(scheme))
                                        Text(option.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                                    }
                                    Spacer()
                                    Icon(name: "chev", size: 12)
                                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(selectedType == option.id ? ReaderStyle.accent.opacity(0.14) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                AIBlock(title: "创作来源 · 已选 \(selectedSources.count)", icon: "stack") {
                    FlowWrap(spacing: 6) {
                        ForEach(store.items.prefix(7)) { source in
                            Chip(
                                title: compact(source.title, limit: 12),
                                selected: selectedSources.contains(source.id),
                                icon: selectedSources.contains(source.id) ? "check" : nil
                            ) {
                                toggleSource(source.id)
                            }
                        }
                    }
                }

                if let error = store.remixError {
                    Text(error)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color(red: 0.82, green: 0.24, blue: 0.24))
                }

                TextIconButton(
                    title: store.isGeneratingRemix ? "生成中" : "生成草稿",
                    icon: "sparkles",
                    role: .primary
                ) {
                    let type = selectedType ?? SampleLibrary.remixOptions.first?.id ?? "rx-note"
                    selectedType = type
                    if selectedSources.isEmpty {
                        selectedSources = [item.id]
                    }
                    store.generateRemix(type: type, selectedSourceIDs: selectedSources)
                }
                .disabled(store.isGeneratingRemix)

                if !store.remixOutput.isEmpty || store.isGeneratingRemix {
                    AIBlock(title: "生成草稿", icon: "sparkles") {
                        Text(store.remixOutput.isEmpty ? "正在生成" : store.remixOutput)
                            .font(.system(size: 13))
                            .lineSpacing(5)
                            .foregroundStyle(ReaderStyle.text(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(13)
                            .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                        HStack(spacing: 8) {
                            TextIconButton(title: "复制", icon: "copy") {
                                copyToPasteboard(store.remixOutput)
                                store.showToast("草稿已复制")
                            }
                            .disabled(store.remixOutput.isEmpty)
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            if selectedSources.isEmpty {
                selectedSources = [item.id]
            }
        }
        .onChange(of: item.id) { _ in
            selectedSources = [item.id]
            selectedType = nil
        }
    }

    private func toggleSource(_ id: String) {
        if selectedSources.contains(id) {
            selectedSources.remove(id)
        } else {
            selectedSources.insert(id)
        }
    }
}

private struct AIBlock<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Icon(name: icon, size: 12)
                Text(title)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            .textCase(.uppercase)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ContextPill: View {
    let icon: String
    let text: String
    let strong: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            Icon(name: icon, size: 13)
                .foregroundStyle(ReaderStyle.accent)
            Text(text)
            Text(strong)
                .fontWeight(.semibold)
                .foregroundStyle(ReaderStyle.text(scheme))
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundStyle(ReaderStyle.secondaryText(scheme))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if message.role == .user {
                Spacer(minLength: 24)
            } else {
                bubbleIcon
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .font(.system(size: 13.5))
                    .lineSpacing(4)
                    .foregroundStyle(message.role == .user ? Color.white : ReaderStyle.text(scheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(bubbleFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                if !message.citations.isEmpty {
                    FlowWrap(spacing: 4) {
                        ForEach(message.citations, id: \.self) { cite in
                            Chip(title: cite, icon: "doc")
                        }
                    }
                }
            }

            if message.role == .user {
                bubbleIcon
            } else {
                Spacer(minLength: 24)
            }
        }
    }

    private var bubbleIcon: some View {
        Icon(name: message.role == .user ? "pencil" : "sparkles", size: 13)
            .foregroundStyle(message.role == .user ? ReaderStyle.secondaryText(scheme) : Color.white)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(message.role == .user ? ReaderStyle.separator(scheme) : ReaderStyle.accent)
            )
    }

    private var bubbleFill: Color {
        message.role == .user ? ReaderStyle.accent : ReaderStyle.controlFill(scheme)
    }
}

private struct TypingRow: View {
    var body: some View {
        HStack(spacing: 9) {
            Icon(name: "sparkles", size: 13)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(ReaderStyle.accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            HStack(spacing: 4) {
                Circle().frame(width: 7, height: 7)
                Circle().frame(width: 7, height: 7)
                Circle().frame(width: 7, height: 7)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Spacer()
        }
    }
}

private func compact(_ text: String, limit: Int = 16) -> String {
    text.count > limit ? String(text.prefix(limit)) + "…" : text
}

private func copyToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
