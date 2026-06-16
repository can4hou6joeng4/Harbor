import AppKit
import ReaderCore
import SwiftUI

struct ReaderDetailView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            if let item = store.selectedItem {
                ReaderToolbar(item: item)

                GeometryReader { proxy in
                    ScrollView {
                        ArticleView(item: item)
                            .frame(maxWidth: CGFloat(store.readingWidth))
                            .padding(.horizontal, 40)
                            .padding(.top, 46)
                            .padding(.bottom, 140)
                            .frame(minWidth: min(CGFloat(store.readingWidth) + 80, proxy.size.width), maxWidth: .infinity)
                            .background(alignment: .top) {
                                ReaderScrollObserver(
                                    itemID: item.id,
                                    restoredOffset: store.readingOffset(for: item.id)
                                ) { state in
                                    store.setReadingOffset(item.id, offset: state.offset)
                                    store.setProgress(item.id, progress: state.progress)
                                }
                                .frame(width: 0, height: 0)
                            }
                    }
                }
            } else {
                EmptyState(icon: "stack", title: "从左侧选择一篇内容开始阅读")
            }
        }
        .background(ReaderStyle.readerBackground(scheme))
    }
}

private struct ReaderToolbar: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    let item: ReaderItem

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [ReaderStyle.amber, Color(red: 0.93, green: 0.78, blue: 0.46)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, proxy.size.width * item.progress), height: 2.5)
                }
            }
            .frame(height: 2.5)

            HStack(spacing: 5) {
                HStack(spacing: 6) {
                    Icon(name: iconName(for: item.kind), size: 14)
                        .foregroundStyle(ReaderStyle.secondaryText(scheme))
                    Text(item.source)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ReaderStyle.secondaryText(scheme))
                        .lineLimit(1)
                }

                Spacer()

                IconButton(icon: "translate", title: "双语对照", isOn: store.bilingual) {
                    store.bilingual.toggle()
                }

                Button {
                    store.typographyOpen.toggle()
                } label: {
                    Text("Aa")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(store.typographyOpen ? ReaderStyle.accent : ReaderStyle.secondaryText(scheme))
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(store.typographyOpen ? ReaderStyle.accent.opacity(0.16) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $store.typographyOpen, arrowEdge: .top) {
                    TypographyPopover()
                        .frame(width: 280)
                        .padding(14)
                }

                IconButton(
                    icon: item.isFavorite ? "star-fill" : "star",
                    title: item.isFavorite ? "取消收藏" : "收藏",
                    tint: item.isFavorite ? ReaderStyle.star : nil
                ) {
                    store.toggleFavorite(item.id)
                }

                IconButton(icon: "share", title: "分享") {
                    store.showToast("分享入口待接入")
                }

                Menu {
                    Button("删除", role: .destructive) {
                        store.requestDeleteItem(item.id)
                    }
                } label: {
                    Icon(name: "ellipsis", size: 16)
                        .foregroundStyle(ReaderStyle.secondaryText(scheme))
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .menuStyle(.borderlessButton)
                .help("更多")

                Rectangle()
                    .fill(ReaderStyle.separator(scheme))
                    .frame(width: 0.5, height: 22)
                    .padding(.horizontal, 4)

                IconButton(icon: "sparkles", title: "AI 助手", isOn: store.aiPanelOpen) {
                    store.aiPanelOpen.toggle()
                }
            }
            .frame(height: ReaderStyle.toolbarHeight)
            .padding(.horizontal, 14)

            Hairline()
        }
    }
}

private struct ArticleView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    let item: ReaderItem

    private var feed: Feed? {
        item.feedID.flatMap { store.feedsByID[$0] }
    }

    private var isVideo: Bool {
        item.kind == .youtube || item.kind == .video
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(item.source)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ReaderStyle.accent)

                if !item.author.isEmpty {
                    Text("·")
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                    Text(item.author)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                }
            }
            .padding(.bottom, 14)

            Text(item.title)
                .font(store.useSerif ? .custom("Iowan Old Style", size: 33).weight(.bold) : .system(size: 33, weight: .bold))
                .lineSpacing(2)
                .foregroundStyle(ReaderStyle.text(scheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Avatar(
                    text: item.author.isEmpty ? item.source : item.author,
                    color: feed.map { Color(hex: $0.colorHex) } ?? ReaderStyle.accent,
                    size: 22
                )
                Text(item.author)
                Text("·")
                Text(item.relativePublishedTime())
                Text("·")
                Text(item.duration.map { "时长 \($0)" } ?? "约 \(item.readingTime ?? 1) 分钟")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ReaderStyle.secondaryText(scheme))
            .padding(.top, 18)
            .padding(.bottom, 26)

            HeroView(item: item)
                .padding(.bottom, heroPadding)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(item.body) { block in
                    ArticleBlockView(block: block, item: item)
                }
            }

            HighlightNotesView(highlights: item.highlights)

            if item.isSummaryOnly, item.url != nil {
                TextIconButton(title: "抓取全文", icon: "link", role: .primary) {
                    store.fetchFullArticle(for: item.id)
                }
                .padding(.top, 28)
            }

            HStack(spacing: 10) {
                Icon(name: "check-circle", size: 15)
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                Text(item.progress >= 0.98 ? "已读完" : "继续阅读 · 进度 \(Int(item.progress * 100))%")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))

                Spacer()

                TextIconButton(title: item.progress >= 0.98 ? "重新开始" : "标记读完", icon: item.progress >= 0.98 ? "clock" : "check") {
                    if item.progress >= 0.98 {
                        store.setProgress(item.id, progress: 0)
                        store.setReadingOffset(item.id, offset: 0)
                    } else {
                        store.setProgress(item.id, progress: 1)
                    }
                }
            }
            .padding(.top, 22)
            .overlay(alignment: .top) {
                Hairline()
            }
            .padding(.top, 40)
        }
    }

    private var heroPadding: CGFloat {
        item.kind == .pdf || item.hasCover || isVideo ? 30 : 0
    }
}

private struct HeroView: View {
    @Environment(\.colorScheme) private var scheme
    let item: ReaderItem

    var body: some View {
        if item.kind == .pdf {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title.replacingOccurrences(of: ".pdf", with: ""))
                    .font(.custom("Iowan Old Style", size: 21).weight(.semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.10))
                Text("Abstract. The dominant sequence transduction models are based on complex recurrent or convolutional neural networks...")
                    .font(.custom("Iowan Old Style", size: 14))
                    .lineSpacing(5)
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.20))
                Text("第 1 页,共 15 页 · 已提取全文")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.gray)
            }
            .padding(38)
            .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(scheme == .dark ? 0.40 : 0.18), radius: 24, y: 12)
        } else if item.kind == .youtube || item.kind == .video {
            ZStack {
                CoverArtwork(coverPath: item.coverPath, hue: item.hue, cornerRadius: 13)
                Circle()
                    .fill(Color.black.opacity(0.48))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Icon(name: "play", size: 26)
                            .foregroundStyle(.white)
                            .padding(.leading, 3)
                    }
                if let duration = item.duration {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(duration)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .padding(12)
                        }
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
        } else if item.hasCover {
            CoverArtwork(coverPath: item.coverPath, hue: item.hue, cornerRadius: 13)
                .frame(height: 240)
        }
    }
}

private struct ArticleBlockView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    let block: ContentBlock
    let item: ReaderItem

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text)
                .font(store.useSerif ? .custom("Iowan Old Style", size: fontSize * 1.34).weight(.bold) : .system(size: fontSize * 1.34, weight: .bold))
                .foregroundStyle(ReaderStyle.text(scheme))
                .lineSpacing(3)
                .padding(.top, fontSize * 1.2)
                .padding(.bottom, fontSize * 0.45)
            translationBlock

        case .quote:
            selectableText(tone: .secondary, italic: true)
                .padding(.leading, 18)
                .padding(.vertical, 4)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(ReaderStyle.accent)
                        .frame(width: 3)
                }
                .padding(.vertical, 12)
            translationBlock

        case .image:
            VStack(spacing: 8) {
                CoverGradient(hue: block.hue ?? item.hue, cornerRadius: 9)
                    .frame(height: 220)
                if let caption = block.caption {
                    Text(caption)
                        .font(.system(size: 12.5))
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical, 18)

        case .lead, .paragraph:
            selectableText(tone: block.kind == .lead ? .secondary : .primary)
                .padding(.bottom, fontSize * 1.05)
            translationBlock
        }
    }

    private var fontSize: CGFloat {
        CGFloat(store.fontSize)
    }

    private var lineSpacing: CGFloat {
        max(0, fontSize * CGFloat(store.lineHeight - 1))
    }

    private func selectableText(
        tone: SelectableArticleTextStyle.Tone,
        italic: Bool = false
    ) -> some View {
        SelectableArticleText(
            text: block.text,
            highlights: item.highlights,
            style: SelectableArticleTextStyle(
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                useSerif: store.useSerif,
                tone: tone,
                italic: italic
            ),
            onHighlight: { selectedText in
                store.addHighlight(itemID: item.id, quote: selectedText)
            },
            onTranslate: { selectedText in
                store.translateSelection(selectedText)
            },
            onAsk: { selectedText in
                store.askAboutSelection(selectedText)
            },
            onNote: { selectedText, note in
                store.addHighlight(itemID: item.id, quote: selectedText, note: note)
            },
            onCopy: { selectedText in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(selectedText, forType: .string)
                store.showToast("已复制")
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var translationBlock: some View {
        if store.bilingual && !block.translation.isEmpty {
            Text(block.translation)
                .font(store.useSerif ? .custom("Iowan Old Style", size: max(14, fontSize - 1)) : .system(size: max(14, fontSize - 1)))
                .lineSpacing(max(2, lineSpacing * 0.85))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                .padding(.leading, 13)
                .padding(.bottom, fontSize * 0.9)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(ReaderStyle.accent.opacity(0.22))
                        .frame(width: 2)
                        .padding(.bottom, fontSize * 0.9)
                }
        }
    }

}

private struct HighlightNotesView: View {
    @Environment(\.colorScheme) private var scheme

    let highlights: [Highlight]

    private var notes: [Highlight] {
        highlights.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Icon(name: "pencil", size: 13)
                    Text("我的笔记")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))

                ForEach(notes) { highlight in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(highlight.quote)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(ReaderStyle.secondaryText(scheme))
                            .lineLimit(2)
                        Text(highlight.note)
                            .font(.system(size: 13.5))
                            .lineSpacing(4)
                            .foregroundStyle(ReaderStyle.text(scheme))
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
}

private struct TypographyPopover: View {
    @EnvironmentObject private var store: ReaderStore

    var body: some View {
        VStack(spacing: 0) {
            TypographyRow(title: "字体") {
                Picker("", selection: $store.useSerif) {
                    Text("衬线").tag(true)
                    Text("无衬线").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            TypographyDivider()

            TypographyRow(title: "字号") {
                StepperControl(valueText: "\(Int(store.fontSize))px") {
                    store.fontSize = max(15, store.fontSize - 1)
                } increment: {
                    store.fontSize = min(23, store.fontSize + 1)
                }
            }

            TypographyDivider()

            TypographyRow(title: "行距") {
                StepperControl(valueText: String(format: "%.2f", store.lineHeight)) {
                    store.lineHeight = max(1.5, store.lineHeight - 0.08)
                } increment: {
                    store.lineHeight = min(2.2, store.lineHeight + 0.08)
                }
            }

            TypographyDivider()

            TypographyRow(title: "栏宽") {
                StepperControl(valueText: "\(Int(store.readingWidth))") {
                    store.readingWidth = max(560, store.readingWidth - 40)
                } increment: {
                    store.readingWidth = min(860, store.readingWidth + 40)
                }
            }

            TypographyDivider()

            TypographyRow(title: "阅读主题") {
                Picker("", selection: $store.themeMode) {
                    Text("日").tag(ReaderThemeMode.light)
                    Text("夜").tag(ReaderThemeMode.dark)
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
            }
        }
    }
}

private struct TypographyRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            control
        }
        .frame(height: 44)
    }
}

private struct TypographyDivider: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(ReaderStyle.separator(scheme))
            .frame(height: 0.5)
    }
}

private struct StepperControl: View {
    let valueText: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            IconButton(icon: "minus", title: "减少", size: 30, iconSize: 12, action: decrement)
            Text(valueText)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .frame(width: 46)
            IconButton(icon: "plus", title: "增加", size: 30, iconSize: 12, action: increment)
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
