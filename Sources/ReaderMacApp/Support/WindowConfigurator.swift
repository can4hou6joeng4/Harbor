import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = "Reader"
            window.minSize = NSSize(width: 1120, height: 720)
            window.setContentSize(NSSize(width: 1380, height: 860))
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
            window.standardWindowButton(.zoomButton)?.isEnabled = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
