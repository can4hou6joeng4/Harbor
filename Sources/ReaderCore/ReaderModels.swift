import Foundation

public struct SmartView: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public let fallbackCount: Int

    public init(id: String, name: String, icon: String, fallbackCount: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.fallbackCount = fallbackCount
    }
}

public struct ReaderTag: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let colorHex: String

    public init(id: String, name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

public struct Feed: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let monogram: String
    public let colorHex: String
    public let count: Int
    public let url: String?
    public let lastFetchedAt: Date?
    public let etag: String?
    public let lastModified: String?

    public init(
        id: String,
        name: String,
        monogram: String,
        colorHex: String,
        count: Int,
        url: String? = nil,
        lastFetchedAt: Date? = nil,
        etag: String? = nil,
        lastModified: String? = nil
    ) {
        self.id = id
        self.name = name
        self.monogram = monogram
        self.colorHex = colorHex
        self.count = count
        self.url = url
        self.lastFetchedAt = lastFetchedAt
        self.etag = etag
        self.lastModified = lastModified
    }
}

public struct PlatformSource: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public let feeds: [Feed]

    public init(id: String, name: String, icon: String, feeds: [Feed]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.feeds = feeds
    }
}

public struct ReaderFolder: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let count: Int
    public let children: [ReaderFolder]

    public init(id: String, name: String, count: Int = 0, children: [ReaderFolder] = []) {
        self.id = id
        self.name = name
        self.count = count
        self.children = children
    }
}

public enum ReaderKind: String, CaseIterable, Codable, Hashable, Sendable {
    case web
    case rss
    case x
    case weibo
    case youtube
    case pdf
    case markdown
    case image
    case video
}

public enum BlockKind: String, Codable, Hashable, Sendable {
    case lead
    case paragraph
    case heading
    case quote
    case image
}

public struct ContentBlock: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var kind: BlockKind
    public var language: String
    public var text: String
    public var translation: String
    public var hue: Double?
    public var caption: String?

    public init(
        id: UUID = UUID(),
        kind: BlockKind,
        language: String,
        text: String,
        translation: String = "",
        hue: Double? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.language = language
        self.text = text
        self.translation = translation
        self.hue = hue
        self.caption = caption
    }
}

public struct Highlight: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var quote: String
    public var note: String
    public var createdAt: Date

    public init(id: UUID = UUID(), quote: String, note: String = "", createdAt: Date = Date()) {
        self.id = id
        self.quote = quote
        self.note = note
        self.createdAt = createdAt
    }
}

public struct ReaderSummary: Codable, Hashable, Sendable {
    public static let summaryOnlyMarker = "summary-only"

    public var text: [String]
    public var keys: [String]
    public var tagSuggestions: [String]

    public init(text: [String], keys: [String], tagSuggestions: [String]) {
        self.text = text
        self.keys = keys
        self.tagSuggestions = tagSuggestions
    }
}

public struct ReaderItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var type: String
    public var kind: ReaderKind
    public var source: String
    public var url: String?
    public var guid: String?
    public var feedID: String?
    public var author: String
    public var title: String
    public var excerpt: String
    public var publishedAt: Date
    public var readingTime: Int?
    public var duration: String?
    public var language: String
    public var tagIDs: [String]
    public var folderID: String
    public var isFavorite: Bool
    public var isUnread: Bool
    public var progress: Double
    public var hue: Double
    public var hasCover: Bool
    public var attachmentPath: String?
    public var coverPath: String?
    public var body: [ContentBlock]
    public var highlights: [Highlight]
    public var summary: ReaderSummary

    public init(
        id: String,
        type: String,
        kind: ReaderKind,
        source: String,
        url: String? = nil,
        guid: String? = nil,
        feedID: String? = nil,
        author: String,
        title: String,
        excerpt: String,
        publishedAt: Date,
        readingTime: Int? = nil,
        duration: String? = nil,
        language: String,
        tagIDs: [String],
        folderID: String,
        isFavorite: Bool,
        isUnread: Bool,
        progress: Double,
        hue: Double,
        hasCover: Bool,
        attachmentPath: String? = nil,
        coverPath: String? = nil,
        body: [ContentBlock],
        highlights: [Highlight] = [],
        summary: ReaderSummary
    ) {
        self.id = id
        self.type = type
        self.kind = kind
        self.source = source
        self.url = url
        self.guid = guid
        self.feedID = feedID
        self.author = author
        self.title = title
        self.excerpt = excerpt
        self.publishedAt = publishedAt
        self.readingTime = readingTime
        self.duration = duration
        self.language = language
        self.tagIDs = tagIDs
        self.folderID = folderID
        self.isFavorite = isFavorite
        self.isUnread = isUnread
        self.progress = progress
        self.hue = hue
        self.hasCover = hasCover
        self.attachmentPath = attachmentPath
        self.coverPath = coverPath
        self.body = body
        self.highlights = highlights
        self.summary = summary
    }

    public func relativePublishedTime(referenceDate: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: publishedAt, relativeTo: referenceDate)
    }

    public var isSummaryOnly: Bool {
        summary.keys.contains(ReaderSummary.summaryOnlyMarker)
    }
}

public enum SortMode: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case unread

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newest: "最新在前"
        case .oldest: "最早在前"
        case .unread: "未读优先"
        }
    }
}

public enum ReaderThemeMode: String, CaseIterable, Identifiable, Sendable {
    case light
    case dark

    public var id: String { rawValue }
}

public enum AITab: String, CaseIterable, Identifiable, Sendable {
    case summary
    case translate
    case chat
    case remix

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .summary: "摘要"
        case .translate: "翻译"
        case .chat: "对话"
        case .remix: "二创"
        }
    }
}

public enum ChatRole: String, Hashable, Sendable {
    case user
    case assistant
}

public struct ChatMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var role: ChatRole
    public var text: String
    public var citations: [String]

    public init(id: UUID = UUID(), role: ChatRole, text: String, citations: [String] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.citations = citations
    }
}

public struct AddContentDraft: Hashable, Sendable {
    public var mode: String
    public var url: String
    public var title: String
    public var markdown: String
    public var tagIDs: [String]
    public var folderID: String

    public init(
        mode: String,
        url: String = "",
        title: String = "",
        markdown: String = "",
        tagIDs: [String] = [],
        folderID: String = "fo-product"
    ) {
        self.mode = mode
        self.url = url
        self.title = title
        self.markdown = markdown
        self.tagIDs = tagIDs
        self.folderID = folderID
    }
}
