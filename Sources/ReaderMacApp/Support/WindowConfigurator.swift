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
        window.minSize = NSSize(width: 1120, height: 720)
        if setInitialSize {
            window.setContentSize(NSSize(width: 1380, height: 860))
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
}
