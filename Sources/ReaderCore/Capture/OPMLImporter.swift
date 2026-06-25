import Foundation

/// A single subscription parsed from an OPML document.
public struct OPMLFeed: Hashable, Sendable {
    public let title: String
    public let xmlURL: String
    public let category: String?

    public init(title: String, xmlURL: String, category: String? = nil) {
        self.title = title
        self.xmlURL = xmlURL
        self.category = category
    }
}

/// Result of importing an OPML file into the library.
public struct OPMLImportSummary: Hashable, Sendable {
    public var total: Int
    public var added: Int
    public var skipped: Int
    public var failed: Int
    public var insertedItems: Int

    public init(total: Int = 0, added: Int = 0, skipped: Int = 0, failed: Int = 0, insertedItems: Int = 0) {
        self.total = total
        self.added = added
        self.skipped = skipped
        self.failed = failed
        self.insertedItems = insertedItems
    }
}

public enum OPMLImportError: LocalizedError, Sendable {
    case invalidData
    case parseFailed(String)
    case noFeeds

    public var errorDescription: String? {
        switch self {
        case .invalidData: return "无法读取 OPML 文件"
        case let .parseFailed(message): return "OPML 解析失败: \(message)"
        case .noFeeds: return "没有在 OPML 中找到订阅源"
        }
    }
}

/// Parses standard OPML subscription exports (the format every RSS reader produces).
///
/// Feed entries are `<outline>` elements carrying an `xmlUrl` attribute; non-feed
/// `<outline>` elements act as categories and become the contained feeds' `category`.
public struct OPMLImporter {
    public init() {}

    public func parse(_ data: Data) throws -> [OPMLFeed] {
        guard !data.isEmpty else { throw OPMLImportError.invalidData }
        let delegate = OPMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw OPMLImportError.parseFailed(parser.parserError?.localizedDescription ?? "未知错误")
        }
        return delegate.feeds
    }

    public func parse(string: String) throws -> [OPMLFeed] {
        guard let data = string.data(using: .utf8) else { throw OPMLImportError.invalidData }
        return try parse(data)
    }
}

private final class OPMLParserDelegate: NSObject, XMLParserDelegate {
    private(set) var feeds: [OPMLFeed] = []
    private var categoryStack: [String] = []
    private var pushedCategory: [Bool] = []   // per <outline> depth: did it push a category?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        guard elementName.lowercased() == "outline" else { return }
        let xmlURL = (attributeDict["xmlUrl"] ?? attributeDict["xmlURL"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (attributeDict["title"] ?? attributeDict["text"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !xmlURL.isEmpty {
            feeds.append(OPMLFeed(title: title.isEmpty ? xmlURL : title, xmlURL: xmlURL, category: categoryStack.last))
            pushedCategory.append(false)
        } else {
            categoryStack.append(title.isEmpty ? "未分类" : title)
            pushedCategory.append(true)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName.lowercased() == "outline" else { return }
        guard let didPush = pushedCategory.popLast() else { return }
        if didPush { _ = categoryStack.popLast() }
    }
}
