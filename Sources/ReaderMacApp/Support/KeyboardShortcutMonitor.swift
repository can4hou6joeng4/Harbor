import AppKit
import ReaderCore
import SwiftUI

struct KeyboardShortcutMonitor: NSViewRepresentable {
    @ObservedObject var store: ReaderStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> KeyboardShortcutMonitorView {
        let view = KeyboardShortcutMonitorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: KeyboardShortcutMonitorView, context: Context) {
        context.coordinator.store = store
        view.coordinator = context.coordinator
    }

    final class Coordinator {
        @MainActor weak var store: ReaderStore?

        @MainActor init(store: ReaderStore) {
            self.store = store
        }

        @MainActor
        func handle(_ event: NSEvent) -> Bool {
            guard let store, canHandleEvent(event, store: store) else {
                return false
            }

            switch event.specialKey {
            case .delete, .deleteForward:
                return store.requestDeleteSelectedItem()
            default:
                break
            }

            guard let character = event.charactersIgnoringModifiers?.lowercased(), character.count == 1 else {
                return false
            }

            switch character {
            case "j":
                return store.selectNextVisibleItem()
            case "k":
                return store.selectPreviousVisibleItem()
            case "f":
                return store.toggleFavoriteOfSelectedItem()
            default:
                return false
            }
        }

        @MainActor
        private func canHandleEvent(_ event: NSEvent, store: ReaderStore) -> Bool {
            guard event.type == .keyDown, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
                return false
            }

            guard !store.commandPaletteOpen,
                  !store.addModalOpen,
                  !store.subscriptionsOpen,
                  !store.aiSettingsSheetOpen,
                  !store.typographyOpen,
                  store.pendingDeleteItem == nil
            else {
                return false
            }

            guard NSApp.modalWindow == nil, NSApp.keyWindow?.attachedSheet == nil else {
                return false
            }

            return !Self.isTextInputFocused
        }

        @MainActor
        private static var isTextInputFocused: Bool {
            guard let responder = NSApp.keyWindow?.firstResponder else { return false }

            if let textView = responder as? NSTextView {
                return textView.isEditable || textView.isFieldEditor
            }

            if responder is NSTextField || responder is NSSearchField {
                return true
            }

            return false
        }
    }
}

final class KeyboardShortcutMonitorView: NSView {
    weak var coordinator: KeyboardShortcutMonitor.Coordinator?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeMonitor()
        } else {
            updateMonitor()
        }
    }

    deinit {
        removeMonitor()
    }

    private func updateMonitor() {
        guard window != nil, monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            var didHandle = false
            MainActor.assumeIsolated {
                didHandle = self?.coordinator?.handle(event) == true
            }
            return didHandle ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
