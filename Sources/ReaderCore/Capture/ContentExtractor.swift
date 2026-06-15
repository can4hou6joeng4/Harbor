import Foundation
import SwiftSoup

public struct ExtractedContent: Hashable, Sendable {
    public var title: String
    public var excerpt: String
    public var author: String
    public var publishedAt: Date
    public var coverImageURL: URL?
    public var blocks: [ContentBlock]
    public var text: String

    public init(
        title: String,
        excerpt: String,
        author: String,
        publishedAt: Date,
        coverImageURL: URL?,
        blocks: [ContentBlock],
        text: String
    ) {
        self.title = title
        self.excerpt = excerpt
        self.author = author
        self.publishedAt = publishedAt
        self.coverImageURL = coverImageURL
        self.blocks = blocks
        self.text = text
    }
}

public protocol ContentExtractor: Sendable {
    func extract(html: String, sourceURL: URL) throws -> ExtractedContent
}

public enum ContentExtractionError: LocalizedError, Sendable {
    case bodyTooShort
    case missingReadableBody

    public var errorDescription: String? {
        switch self {
        case .bodyTooShort, .missingReadableBody:
            return "未能提取正文"
        }
    }
}

public struct SwiftSoupExtractor: ContentExtractor {
    private let minimumBodyLength: Int
    private let noisyPattern = try? NSRegularExpression(
        pattern: "(^|[-_\\s])(ad|banner|promo|comment|sidebar|related)([-_\\s]|$)",
        options: [.caseInsensitive]
    )

    public init(minimumBodyLength: Int = 200) {
        self.minimumBodyLength = minimumBodyLength
    }

    public func extract(html: String, sourceURL: URL) throws -> ExtractedContent {
        let document = try SwiftSoup.parse(html, sourceURL.absoluteString)
        try clean(document)

        guard let container = try readableContainer(in: document) else {
            throw ContentExtractionError.missingReadableBody
        }

        let blocks = try contentBlocks(from: container, sourceURL: sourceURL)
        let text = normalized(
            blocks
                .filter { $0.kind != .image }
                .map(\.text)
                .joined(separator: "\n")
        )
        guard text.count >= minimumBodyLength else {
            throw ContentExtractionError.bodyTooShort
        }

        let fallbackTitle = try normalized(document.title())
        let title = try metaContent(in: document, keys: ["og:title", "twitter:title"])
            ?? (fallbackTitle.isEmpty ? sourceURL.host ?? "网页" : fallbackTitle)
        let excerpt = try metaContent(in: document, keys: ["og:description", "description", "twitter:description"])
            ?? String(text.prefix(100))
        let author = try metaContent(in: document, keys: ["author", "article:author"])
            ?? sourceURL.host?.replacingOccurrences(of: "www.", with: "")
            ?? "网页"
        let publishedAt = try publishedDate(in: document) ?? Date()
        let coverImageURL = try metaContent(in: document, keys: ["og:image", "twitter:image"])
            .flatMap { URL(string: $0, relativeTo: sourceURL)?.absoluteURL }

        return ExtractedContent(
            title: normalized(title),
            excerpt: normalized(excerpt),
            author: normalized(author),
            publishedAt: publishedAt,
            coverImageURL: coverImageURL,
            blocks: blocks,
            text: text
        )
    }

    private func clean(_ document: Document) throws {
        try document.select("script, style, nav, header, footer, aside, form, iframe").remove()
        for element in try document.select("[class], [id]").array() {
            let marker = try [element.className(), element.id()].joined(separator: " ")
            guard matchesNoisyPattern(marker) else { continue }
            try element.remove()
        }
    }

    private func readableContainer(in document: Document) throws -> Element? {
        if let article = try document.select("article").first(), try !normalized(article.text()).isEmpty {
            return article
        }

        if let main = try document.select("[role=main], main").first(), try !normalized(main.text()).isEmpty {
            return main
        }

        let candidates = try document.select("section, div, body").array()
        return try candidates.max { lhs, rhs in
            try densityScore(lhs) < densityScore(rhs)
        }
    }

    private func densityScore(_ element: Element) throws -> Double {
        let text = try normalized(element.text())
        guard !text.isEmpty else { return 0 }

        let paragraphCount = max(1, try element.select("p").array().count)
        let linkTextLength = try normalized(element.select("a").text()).count
        let linkRatio = Double(linkTextLength) / Double(max(text.count, 1))
        return Double(text.count * paragraphCount) / (1 + linkRatio)
    }

    private func contentBlocks(from container: Element, sourceURL: URL) throws -> [ContentBlock] {
        let elements = try container.select("p, h2, h3, h4, blockquote, figure, img").array()
        var blocks: [ContentBlock] = []
        var hasLead = false

        for element in elements {
            let tag = element.tagName().lowercased()
            switch tag {
            case "p":
                let text = try normalized(element.text())
                guard !text.isEmpty else { continue }
                blocks.append(ContentBlock(kind: hasLead ? .paragraph : .lead, language: "", text: text))
                hasLead = true
            case "h2", "h3", "h4":
                let text = try normalized(element.text())
                guard !text.isEmpty else { continue }
                blocks.append(ContentBlock(kind: .heading, language: "", text: text))
            case "blockquote":
                let text = try normalized(element.text())
                guard !text.isEmpty else { continue }
                blocks.append(ContentBlock(kind: .quote, language: "", text: text))
            case "figure":
                if let image = try element.select("img").first(), let block = try imageBlock(from: image, figure: element, sourceURL: sourceURL) {
                    blocks.append(block)
                }
            case "img":
                if let parent = element.parent(), parent.tagName().lowercased() == "figure" {
                    continue
                }
                if let block = try imageBlock(from: element, figure: nil, sourceURL: sourceURL) {
                    blocks.append(block)
                }
            default:
                continue
            }
        }

        if blocks.isEmpty {
            let fallback = try normalized(container.text())
            if !fallback.isEmpty {
                blocks.append(ContentBlock(kind: .lead, language: "", text: fallback))
            }
        }

        return blocks
    }

    private func imageBlock(from image: Element, figure: Element?, sourceURL: URL) throws -> ContentBlock? {
        let alt = try normalized(image.attr("alt"))
        let widthHint = Int(try image.attr("width").filter(\.isNumber)) ?? 0
        guard !alt.isEmpty || widthHint >= 200 else {
            return nil
        }

        let src = try image.attr("src")
        let resolved = URL(string: src, relativeTo: sourceURL)?.absoluteString ?? src
        let figcaption: String?
        if let figure {
            figcaption = try figure.select("figcaption").first()?.text()
        } else {
            figcaption = nil
        }
        let caption = normalized(figcaption ?? alt)
        return ContentBlock(
            kind: .image,
            language: "",
            text: resolved,
            caption: caption.isEmpty ? nil : caption
        )
    }

    private func metaContent(in document: Document, keys: [String]) throws -> String? {
        let wanted = Set(keys.map { $0.lowercased() })
        for meta in try document.select("meta").array() {
            let property = try meta.attr("property").lowercased()
            let name = try meta.attr("name").lowercased()
            guard wanted.contains(property) || wanted.contains(name) else {
                continue
            }

            let content = try normalized(meta.attr("content"))
            if !content.isEmpty {
                return content
            }
        }
        return nil
    }

    private func publishedDate(in document: Document) throws -> Date? {
        guard let raw = try metaContent(in: document, keys: ["article:published_time", "published_time", "date"]) else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: raw) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private func matchesNoisyPattern(_ value: String) -> Bool {
        guard let noisyPattern else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return noisyPattern.firstMatch(in: value, range: range) != nil
    }

    private func normalized(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
