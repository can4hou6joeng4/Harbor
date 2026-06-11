import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window, setInitialSize: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                configure(window, setInitialSize: false)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window, setInitialSize: false)
        }
    }

    private func configure(_ window: NSWindow, setInitialSize: Bool) {
        window.title = "Reader"
        window.minSize = NSSize(
            width: ReaderStyle.minimumWindowSize.width,
            height: ReaderStyle.minimumWindowSize.height
        )
        if setInitialSize {
            let frame = Self.initialFrame(for: window)
            window.setFrame(frame, display: true)
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)

        [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ].forEach { buttonType in
            guard let button = window.standardWindowButton(buttonType) else { return }
            button.isHidden = true
            button.alphaValue = 0
            button.isEnabled = false
            button.setFrameOrigin(NSPoint(x: -1000, y: button.frame.origin.y))
        }
    }

    private static func initialFrame(for window: NSWindow) -> NSRect {
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(
            x: 0,
            y: 0,
            width: ReaderStyle.preferredWindowSize.width,
            height: ReaderStyle.preferredWindowSize.height
        )
        let width = min(ReaderStyle.preferredWindowSize.width, visibleFrame.width - 48)
        let height = min(ReaderStyle.preferredWindowSize.height, visibleFrame.height - 48)
        let size = NSSize(
            width: max(ReaderStyle.minimumWindowSize.width, width),
            height: max(ReaderStyle.minimumWindowSize.height, height)
        )
        return NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
