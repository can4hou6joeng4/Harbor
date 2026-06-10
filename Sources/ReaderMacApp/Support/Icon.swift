import ReaderCore
import SwiftUI

struct Icon: View {
    let name: String
    var size: CGFloat = 16
    var weight: Font.Weight = .medium

    var body: some View {
        Image(systemName: symbolName(for: name))
            .font(.system(size: size, weight: weight))
            .frame(width: size + 2, height: size + 2)
    }

    private func symbolName(for name: String) -> String {
        switch name {
        case "archive": "archivebox"
        case "bookmark": "bookmark"
        case "calendar": "calendar"
        case "chat": "bubble.left.and.bubble.right"
        case "check": "checkmark"
        case "check-circle": "checkmark.circle.fill"
        case "chev": "chevron.right"
        case "clock": "clock"
        case "close": "xmark"
        case "copy": "doc.on.doc"
        case "doc": "doc.text"
        case "dot": "circle.fill"
        case "ellipsis": "ellipsis"
        case "eye": "eye"
        case "folder": "folder"
        case "gear": "gearshape"
        case "globe": "globe"
        case "highlighter": "highlighter"
        case "inbox": "tray"
        case "link": "link"
        case "list": "list.bullet"
        case "markdown": "curlybraces"
        case "minus": "minus"
        case "moon": "moon"
        case "panel-right": "sidebar.right"
        case "paperclip": "paperclip"
        case "pencil": "pencil"
        case "play": "play.fill"
        case "plus": "plus"
        case "rss": "dot.radiowaves.left.and.right"
        case "search": "magnifyingglass"
        case "send": "paperplane.fill"
        case "share": "square.and.arrow.up"
        case "sort": "arrow.up.arrow.down"
        case "sparkles": "sparkles"
        case "stack": "square.stack"
        case "star": "star"
        case "star-fill": "star.fill"
        case "sun": "sun.max"
        case "tag": "tag"
        case "translate": "character.book.closed"
        case "wand": "wand.and.stars"
        case "weibo": "bubble.left"
        case "x": "xmark"
        case "youtube": "play.rectangle"
        default: name
        }
    }
}

func iconName(for kind: ReaderKind) -> String {
    switch kind {
    case .web: "globe"
    case .rss: "rss"
    case .x: "x"
    case .weibo: "weibo"
    case .youtube: "youtube"
    case .pdf: "doc"
    case .markdown: "markdown"
    case .image: "photo"
    case .video: "play"
    }
}
