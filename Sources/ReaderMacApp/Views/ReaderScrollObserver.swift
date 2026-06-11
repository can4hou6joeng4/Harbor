import AppKit
import SwiftUI

struct ReaderScrollState: Equatable {
    var offset: Double
    var progress: Double
}

struct ReaderScrollObserver: NSViewRepresentable {
    let itemID: String
    let restoredOffset: Double
    let onScroll: (ReaderScrollState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ScrollObserverView {
        let view = ScrollObserverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: ScrollObserverView, context: Context) {
        context.coordinator.itemID = itemID
        context.coordinator.restoredOffset = restoredOffset
        context.coordinator.onScroll = onScroll
        view.coordinator = context.coordinator

        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: view)
            context.coordinator.restoreIfNeeded()
        }
    }

    final class Coordinator {
        var itemID = ""
        var restoredOffset: Double = 0
        var onScroll: ((ReaderScrollState) -> Void)?

        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?
        private var restoredItemID: String?
        private var scheduledRestoreItemID: String?
        private var lastReportedState: ReaderScrollState?
        private var isRestoring = false

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attachIfNeeded(from view: NSView) {
            guard let nextScrollView = view.enclosingScrollView, scrollView !== nextScrollView else {
                return
            }

            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }

            scrollView = nextScrollView
            nextScrollView.contentView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: nextScrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.reportScroll()
            }
        }

        func restoreIfNeeded() {
            guard restoredItemID != itemID, scheduledRestoreItemID != itemID, scrollView != nil else { return }
            scheduledRestoreItemID = itemID

            DispatchQueue.main.async { [weak self] in
                self?.performRestore()
            }
        }

        private func performRestore(retryCount: Int = 0) {
            guard let scrollView else {
                scheduledRestoreItemID = nil
                return
            }
            guard let documentView = scrollView.documentView else {
                guard retryCount < 4 else {
                    scheduledRestoreItemID = nil
                    return
                }
                retryRestore(retryCount)
                return
            }

            let viewportHeight = scrollView.contentView.bounds.height
            let contentHeight = documentView.bounds.height
            let maxOffset = max(0, contentHeight - viewportHeight)

            if contentHeight <= 1, retryCount < 4 {
                retryRestore(retryCount)
                return
            }

            let targetOffset = min(max(0, CGFloat(restoredOffset)), maxOffset)
            isRestoring = true
            scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.origin.x, y: targetOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            isRestoring = false
            restoredItemID = itemID
            scheduledRestoreItemID = nil
            reportScroll(force: true)
        }

        private func retryRestore(_ retryCount: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                self?.performRestore(retryCount: retryCount + 1)
            }
        }

        private func reportScroll(force: Bool = false) {
            guard !isRestoring || force, let scrollView, let documentView = scrollView.documentView else {
                return
            }

            let viewportHeight = scrollView.contentView.bounds.height
            let contentHeight = documentView.bounds.height
            let maxOffset = max(0, contentHeight - viewportHeight)
            let offset = min(max(0, scrollView.contentView.bounds.origin.y), maxOffset)
            let progress = maxOffset > 0 ? min(max(Double(offset / maxOffset), 0), 1) : 0
            let state = ReaderScrollState(offset: Double(offset), progress: progress)

            if !force, let lastReportedState, abs(lastReportedState.offset - state.offset) < 4 {
                return
            }

            lastReportedState = state
            onScroll?(state)
        }
    }
}

final class ScrollObserverView: NSView {
    weak var coordinator: ReaderScrollObserver.Coordinator?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            coordinator?.attachIfNeeded(from: self)
            coordinator?.restoreIfNeeded()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            coordinator?.attachIfNeeded(from: self)
            coordinator?.restoreIfNeeded()
        }
    }
}
