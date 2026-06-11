import AppKit
import ReaderCore
import SwiftUI

struct SelectableArticleTextStyle: Equatable {
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    var useSerif: Bool
    var tone: Tone
    var italic = false

    enum Tone: Equatable {
        case primary
        case secondary
    }
}

struct SelectableArticleText: View {
    let text: String
    let highlights: [Highlight]
    let style: SelectableArticleTextStyle
    let onHighlight: (String) -> Void
    let onTranslate: (String) -> Void
    let onAsk: (String) -> Void
    let onNote: (String, String) -> Void
    let onCopy: (String) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var measuredHeight: CGFloat = 1

    var body: some View {
        SelectableArticleTextRepresentable(
            text: text,
            highlights: highlights,
            style: style,
            scheme: scheme,
            measuredHeight: $measuredHeight,
            onHighlight: onHighlight,
            onTranslate: onTranslate,
            onAsk: onAsk,
            onNote: onNote,
            onCopy: onCopy
        )
        .frame(height: max(1, measuredHeight))
    }
}

private struct SelectableArticleTextRepresentable: NSViewRepresentable {
    let text: String
    let highlights: [Highlight]
    let style: SelectableArticleTextStyle
    let scheme: ColorScheme
    @Binding var measuredHeight: CGFloat
    let onHighlight: (String) -> Void
    let onTranslate: (String) -> Void
    let onAsk: (String) -> Void
    let onNote: (String, String) -> Void
    let onCopy: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> ArticleTextView {
        let textView = ArticleTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.importsGraphics = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.onSelectionFinalized = { [weak coordinator = context.coordinator, weak textView] in
            guard let textView else { return }
            coordinator?.presentSelection(from: textView)
        }
        textView.onMouseDownInText = { [weak coordinator = context.coordinator] in
            coordinator?.dismissPanels()
        }
        textView.onHeightChange = { [weak coordinator = context.coordinator] height in
            coordinator?.setMeasuredHeight(height)
        }
        context.coordinator.textView = textView
        return textView
    }

    func updateNSView(_ textView: ArticleTextView, context: Context) {
        context.coordinator.parent = self
        textView.onHeightChange = { [weak coordinator = context.coordinator] height in
            coordinator?.setMeasuredHeight(height)
        }

        let signature = RenderSignature(text: text, highlights: highlights, style: style, scheme: scheme)
        if context.coordinator.renderSignature != signature {
            textView.textStorage?.setAttributedString(Self.attributedText(for: signature))
            context.coordinator.renderSignature = signature
        }

        textView.needsLayout = true
        textView.reportHeightIfNeeded()

        DispatchQueue.main.async {
            context.coordinator.attachScrollObserver(from: textView)
        }
    }

    private static func attributedText(for signature: RenderSignature) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = signature.style.lineSpacing

        let attributed = NSMutableAttributedString(
            string: signature.text,
            attributes: [
                .font: font(for: signature.style),
                .foregroundColor: textColor(for: signature.style.tone, scheme: signature.scheme),
                .paragraphStyle: paragraphStyle
            ]
        )

        applyHighlights(to: attributed, signature: signature)
        return attributed
    }

    private static func font(for style: SelectableArticleTextStyle) -> NSFont {
        let base = style.useSerif
            ? NSFont(name: "Iowan Old Style", size: style.fontSize) ?? NSFont.systemFont(ofSize: style.fontSize)
            : NSFont.systemFont(ofSize: style.fontSize)

        guard style.italic else { return base }
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
    }

    private static func textColor(for tone: SelectableArticleTextStyle.Tone, scheme: ColorScheme) -> NSColor {
        switch (tone, scheme) {
        case (.primary, .dark):
            return NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.89, alpha: 0.92)
        case (.primary, _):
            return NSColor(calibratedRed: 0.16, green: 0.15, blue: 0.12, alpha: 0.90)
        case (.secondary, .dark):
            return NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.82, alpha: 0.55)
        case (.secondary, _):
            return NSColor(calibratedRed: 0.21, green: 0.19, blue: 0.16, alpha: 0.60)
        }
    }

    private static func applyHighlights(to attributed: NSMutableAttributedString, signature: RenderSignature) {
        guard !signature.highlights.isEmpty else { return }

        let nsText = signature.text as NSString
        var occupied: [NSRange] = []
        let highlightColor = NSColor(calibratedRed: 0.83, green: 0.59, blue: 0.25, alpha: signature.scheme == .dark ? 0.20 : 0.27)
        let noteColor = NSColor(calibratedRed: 0.83, green: 0.59, blue: 0.25, alpha: signature.scheme == .dark ? 0.28 : 0.36)
        let accentColor = NSColor(calibratedRed: 0.29, green: 0.45, blue: 0.74, alpha: 0.80)

        for highlight in signature.highlights {
            let quote = highlight.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty else { continue }

            let fullRange = NSRange(location: 0, length: nsText.length)
            let foundRange = nsText.range(
                of: quote,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: fullRange
            )
            guard foundRange.location != NSNotFound, !occupied.contains(where: { NSIntersectionRange($0, foundRange).length > 0 }) else {
                continue
            }

            let hasNote = !highlight.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            attributed.addAttributes(
                [
                    .backgroundColor: hasNote ? noteColor : highlightColor,
                    .underlineStyle: hasNote ? NSUnderlineStyle.single.rawValue : 0,
                    .underlineColor: accentColor
                ],
                range: foundRange
            )
            occupied.append(foundRange)
        }
    }
}

private struct RenderSignature: Equatable {
    let text: String
    let highlights: [Highlight]
    let style: SelectableArticleTextStyle
    let scheme: ColorScheme
}

private final class ArticleTextView: NSTextView {
    var onSelectionFinalized: (() -> Void)?
    var onMouseDownInText: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    private var lastReportedHeight: CGFloat = 0

    override func mouseDown(with event: NSEvent) {
        onMouseDownInText?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onSelectionFinalized?()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        textContainer?.containerSize = NSSize(width: max(1, newSize.width), height: .greatestFiniteMagnitude)
        reportHeightIfNeeded()
    }

    override func layout() {
        super.layout()
        reportHeightIfNeeded()
    }

    func reportHeightIfNeeded() {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let nextHeight = ceil(max(1, usedRect.height + textContainerInset.height * 2 + 1))

        guard abs(nextHeight - lastReportedHeight) > 0.5 else { return }
        lastReportedHeight = nextHeight

        DispatchQueue.main.async { [weak self] in
            self?.onHeightChange?(nextHeight)
        }
    }
}

private final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: SelectableArticleTextRepresentable
    var renderSignature: RenderSignature?
    weak var textView: ArticleTextView?

    private var selectionPanel: FloatingArticlePanel?
    private var notePanel: FloatingArticlePanel?
    private weak var observedScrollView: NSScrollView?
    private var scrollObserver: NSObjectProtocol?

    init(parent: SelectableArticleTextRepresentable) {
        self.parent = parent
    }

    deinit {
        dismissPanels()
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
    }

    func setMeasuredHeight(_ height: CGFloat) {
        guard abs(parent.measuredHeight - height) > 0.5 else { return }
        parent.measuredHeight = height
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView.selectedRange().length == 0 else {
            return
        }
        dismissPanels()
    }

    func presentSelection(from textView: NSTextView) {
        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else {
            dismissPanels()
            return
        }

        let selected = (textView.string as NSString).substring(with: selectedRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard selected.count >= 2, let screenRect = selectionScreenRect(in: textView, selectedRange: selectedRange), let ownerWindow = textView.window else {
            dismissPanels()
            return
        }

        showSelectionPanel(for: selected, near: screenRect, ownerWindow: ownerWindow)
    }

    func attachScrollObserver(from view: NSView) {
        guard let scrollView = view.enclosingScrollView, observedScrollView !== scrollView else { return }

        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }

        observedScrollView = scrollView
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.dismissPanels()
        }
    }

    func dismissPanels() {
        close(panel: &selectionPanel)
        close(panel: &notePanel)
    }

    private func selectionScreenRect(in textView: NSTextView, selectedRange: NSRange) -> NSRect? {
        guard
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let window = textView.window
        else {
            return nil
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        guard !rect.isEmpty else { return nil }

        rect.origin.x += textView.textContainerOrigin.x
        rect.origin.y += textView.textContainerOrigin.y

        let windowRect = textView.convert(rect, to: nil)
        return window.convertToScreen(windowRect)
    }

    private func showSelectionPanel(for selected: String, near screenRect: NSRect, ownerWindow: NSWindow) {
        close(panel: &selectionPanel)
        close(panel: &notePanel)

        let panelSize = NSSize(width: 382, height: 40)
        let panel = FloatingArticlePanel(size: panelSize)
        panel.contentView = NSHostingView(
            rootView: SelectionActionBar(
                onHighlight: { [weak self] in
                    self?.parent.onHighlight(selected)
                    self?.dismissPanels()
                    self?.textView?.setSelectedRange(NSRange(location: 0, length: 0))
                },
                onTranslate: { [weak self] in
                    self?.parent.onTranslate(selected)
                    self?.dismissPanels()
                    self?.textView?.setSelectedRange(NSRange(location: 0, length: 0))
                },
                onAsk: { [weak self] in
                    self?.parent.onAsk(selected)
                    self?.dismissPanels()
                    self?.textView?.setSelectedRange(NSRange(location: 0, length: 0))
                },
                onNote: { [weak self] in
                    self?.showNotePanel(for: selected, near: screenRect, ownerWindow: ownerWindow)
                },
                onCopy: { [weak self] in
                    self?.parent.onCopy(selected)
                    self?.dismissPanels()
                    self?.textView?.setSelectedRange(NSRange(location: 0, length: 0))
                }
            )
            .frame(width: panelSize.width, height: panelSize.height)
        )

        position(panel, size: panelSize, near: screenRect, ownerWindow: ownerWindow, placement: .above)
        ownerWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        selectionPanel = panel
    }

    private func showNotePanel(for selected: String, near screenRect: NSRect, ownerWindow: NSWindow) {
        close(panel: &selectionPanel)
        close(panel: &notePanel)

        let panelSize = NSSize(width: 320, height: 188)
        let panel = FloatingArticlePanel(size: panelSize)
        panel.contentView = NSHostingView(
            rootView: SelectionNotePanel(
                quote: selected,
                onCancel: { [weak self] in
                    self?.dismissPanels()
                    self?.textView?.setSelectedRange(NSRange(location: 0, length: 0))
                },
                onSave: { [weak self] note in
                    self?.parent.onNote(selected, note)
                    self?.dismissPanels()
                    self?.textView?.setSelectedRange(NSRange(location: 0, length: 0))
                }
            )
            .frame(width: panelSize.width, height: panelSize.height)
        )

        position(panel, size: panelSize, near: screenRect, ownerWindow: ownerWindow, placement: .below)
        ownerWindow.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        notePanel = panel
    }

    private func position(
        _ panel: NSPanel,
        size: NSSize,
        near rect: NSRect,
        ownerWindow: NSWindow,
        placement: PanelPlacement
    ) {
        let visible = ownerWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let x = min(max(visible.minX + 10, rect.midX - size.width / 2), visible.maxX - size.width - 10)
        let preferredY: CGFloat
        let fallbackY: CGFloat

        switch placement {
        case .above:
            preferredY = rect.maxY + 8
            fallbackY = rect.minY - size.height - 8
        case .below:
            preferredY = rect.minY - size.height - 10
            fallbackY = rect.maxY + 10
        }

        let y = preferredY < visible.minY || preferredY + size.height > visible.maxY ? fallbackY : preferredY
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    private func close(panel: inout FloatingArticlePanel?) {
        guard let existing = panel else { return }
        existing.parent?.removeChildWindow(existing)
        existing.close()
        panel = nil
    }
}

private enum PanelPlacement {
    case above
    case below
}

private final class FloatingArticlePanel: NSPanel {
    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = true
        collectionBehavior = [.transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct SelectionActionBar: View {
    let onHighlight: () -> Void
    let onTranslate: () -> Void
    let onAsk: () -> Void
    let onNote: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 1) {
            SelectionActionButton(title: "高亮", icon: "highlighter", action: onHighlight)
            SelectionActionButton(title: "翻译", icon: "translate", action: onTranslate)
            SelectionActionButton(title: "追问 AI", icon: "chat", action: onAsk)

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 0.5, height: 18)
                .padding(.horizontal, 2)

            SelectionActionButton(title: "笔记", icon: "pencil", action: onNote)
            SelectionActionButton(title: "复制", icon: "copy", action: onCopy)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
    }
}

private struct SelectionActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Icon(name: icon, size: 14)
                Text(title)
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.84))
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SelectionNotePanel: View {
    let quote: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(previewQuote)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                .lineLimit(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextEditor(text: $note)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(height: 72)
                .background(ReaderStyle.controlFill(scheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
                }
                .focused($focused)

            HStack(spacing: 8) {
                Spacer()
                TextIconButton(title: "取消", icon: "close", action: onCancel)
                TextIconButton(title: "保存", icon: "check", role: .primary) {
                    onSave(note)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
        }
        .onAppear {
            focused = true
        }
    }

    private var previewQuote: String {
        quote.count > 90 ? "\(quote.prefix(90))..." : quote
    }
}
