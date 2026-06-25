import Foundation
import NaturalLanguage

public struct CapturedArticle: Hashable, Sendable {
    public var originalURL: URL
    public var finalURL: URL
    public var source: String
    public var author: String
    public var title: String
    public var excerpt: String
    public var publishedAt: Date
    public var readingTime: Int
    public var language: String
    public var hue: Double
    public var coverPath: String?
    public var body: [ContentBlock]

    public init(
        originalURL: URL,
        finalURL: URL,
        source: String,
        author: String,
        title: String,
        excerpt: String,
        publishedAt: Date,
        readingTime: Int,
        language: String,
        hue: Double,
        coverPath: String?,
        body: [ContentBlock]
    ) {
        self.originalURL = originalURL
        self.finalURL = finalURL
        self.source = source
        self.author = author
        self.title = title
        self.excerpt = excerpt
        self.publishedAt = publishedAt
        self.readingTime = readingTime
        self.language = language
        self.hue = hue
        self.coverPath = coverPath
        self.body = body
    }
}

public enum CaptureError: LocalizedError, Sendable {
    case invalidURL
    case nonHTMLContent(String?)
    case extractionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL 无效"
        case .nonHTMLContent:
            return "链接不是可提取的 HTML 页面"
        case .extractionFailed:
            return "未能提取正文"
        }
    }
}

public final class CaptureService: @unchecked Sendable {
    private let repository: any ReaderRepository
    private let httpClient: any HTTPClient
    private let extractor: any ContentExtractor
    private let assetStore: any CaptureAssetStore
    private let now: @Sendable () -> Date

    public init(
        repository: any ReaderRepository,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        extractor: any ContentExtractor = SwiftSoupExtractor(),
        assetStore: (any CaptureAssetStore)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.httpClient = httpClient
        self.extractor = extractor
        if let assetStore {
            self.assetStore = assetStore
        } else {
            self.assetStore = (try? LocalCaptureAssetStore()) ?? NoopCaptureAssetStore()
        }
        self.now = now
    }

    public func preview(urlString: String) async throws -> CapturedArticle {
        let originalURL = try normalizedURL(from: urlString)
        let response = try await httpClient.fetch(
            CaptureRequest(
                url: originalURL,
                headers: ["Accept": "text/html,application/xhtml+xml"]
            )
        )
        guard response.isHTML else {
            throw CaptureError.nonHTMLContent(response.mimeType)
        }

        let extracted: ExtractedContent
        do {
            extracted = try extractor.extract(html: response.decodedText(), sourceURL: response.url)
        } catch is ContentExtractionError {
            throw CaptureError.extractionFailed
        }

        let language = Self.detectLanguage(in: extracted.text)
        let coverPath = await downloadCoverIfAvailable(extracted.coverImageURL)
        let body = extracted.blocks.map { block in
            var copy = block
            copy.language = language
            return copy
        }

        return CapturedArticle(
            originalURL: originalURL,
            finalURL: response.url,
            source: Self.domain(from: response.url),
            author: extracted.author,
            title: extracted.title,
            excerpt: extracted.excerpt,
            publishedAt: extracted.publishedAt,
            readingTime: Self.readingTime(for: extracted.text),
            language: language,
            hue: Self.hue(for: "\(response.url.absoluteString) \(extracted.title)"),
            coverPath: coverPath,
            body: body
        )
    }

    public func save(_ article: CapturedArticle, tagIDs: [String], folderID: String) async throws -> ReaderItem {
        let item = ReaderItem(
            id: UUID().uuidString,
            type: "article",
            kind: .web,
            source: article.source,
            url: article.finalURL.absoluteString,
            author: article.author,
            title: article.title,
            excerpt: article.excerpt,
            publishedAt: article.publishedAt,
            readingTime: article.readingTime,
            language: article.language,
            tagIDs: tagIDs,
            folderID: folderID,
            isFavorite: false,
            isUnread: true,
            progress: 0,
            hue: article.hue,
            hasCover: article.coverPath != nil,
            coverPath: article.coverPath,
            body: article.body,
            summary: ReaderSummary(
                text: [article.excerpt],
                keys: [],
                tagSuggestions: []
            )
        )
        try await repository.saveItem(item)
        return item
    }

    /// Bulk-imports read-later entries as lightweight, summary-only items (no network
    /// fetch — each can pull its full text on demand). Skips URLs already in the library.
    public func importReadLater(_ entries: [ReadLaterEntry], existingURLs: Set<String>) async -> ReadLaterImportSummary {
        var seen = existingURLs
        var added = 0
        var skipped = 0
        var failed = 0
        for entry in entries {
            guard let url = try? FeedSyncService.normalizedURL(from: entry.url) else { failed += 1; continue }
            let key = url.absoluteString
            if seen.contains(key) { skipped += 1; continue }
            seen.insert(key)
            let item = Self.makeImportedItem(url: url, entry: entry, fallbackDate: now())
            do {
                try await repository.saveItem(item)
                added += 1
            } catch {
                failed += 1
            }
        }
        return ReadLaterImportSummary(total: entries.count, added: added, skipped: skipped, failed: failed)
    }

    static func makeImportedItem(url: URL, entry: ReadLaterEntry, fallbackDate: Date) -> ReaderItem {
        let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? "网页"
        let trimmedTitle = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (trimmedTitle?.isEmpty == false ? trimmedTitle : nil) ?? host
        let hue = Double(url.absoluteString.utf8.reduce(0) { $0 &+ Int($1) } % 360)
        return ReaderItem(
            id: UUID().uuidString,
            type: "article",
            kind: .web,
            source: host,
            url: url.absoluteString,
            guid: url.absoluteString,
            author: "",
            title: title,
            excerpt: "已从稍后读导入,点击可抓取全文。",
            publishedAt: entry.addedAt ?? fallbackDate,
            language: "en",
            tagIDs: [],
            folderID: "",
            isFavorite: entry.isFavorite,
            isUnread: !entry.isArchived,
            progress: entry.isArchived ? 1 : 0,
            hue: hue,
            hasCover: false,
            body: [],
            summary: ReaderSummary(text: [], keys: [ReaderSummary.summaryOnlyMarker], tagSuggestions: [])
        )
    }

    private func downloadCoverIfAvailable(_ url: URL?) async -> String? {
        guard let url else { return nil }
        do {
            let response = try await httpClient.fetch(
                CaptureRequest(url: url, headers: ["Accept": "image/*"])
            )
            guard response.mimeType?.hasPrefix("image/") == true else {
                return nil
            }
            return try await assetStore.store(
                data: response.data,
                preferredExtension: response.preferredImageExtension(fallbackURL: url)
            )
        } catch {
            return nil
        }
    }

    private func normalizedURL(from raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureError.invalidURL
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            throw CaptureError.invalidURL
        }
        return url
    }

    private static func detectLanguage(in text: String) -> String {
        let prefix = String(text.prefix(500))
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(prefix)

        switch recognizer.dominantLanguage {
        case .simplifiedChinese, .traditionalChinese:
            return "zh"
        case .some(let language) where language.rawValue.hasPrefix("zh"):
            return "zh"
        default:
            return prefix.unicodeScalars.contains(where: \.isCJK) ? "zh" : "en"
        }
    }

    private static func readingTime(for text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / 500.0)))
    }

    private static func hue(for value: String) -> Double {
        let hash = abs(value.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return Double(hash % 360)
    }

    private static func domain(from url: URL) -> String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? "网页"
    }
}

private struct NoopCaptureAssetStore: CaptureAssetStore {
    func store(data: Data, preferredExtension: String) async throws -> String {
        throw CaptureAssetStoreError.invalidExtension
    }
}

private extension CaptureResponse {
    var isHTML: Bool {
        guard let mimeType else { return true }
        return mimeType == "text/html" || mimeType == "application/xhtml+xml"
    }

    func preferredImageExtension(fallbackURL: URL) -> String {
        if let pathExtension = fallbackURL.pathExtension.nilIfEmpty {
            return pathExtension
        }

        switch mimeType {
        case "image/jpeg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        default:
            return suggestedFilename.flatMap { URL(fileURLWithPath: $0).pathExtension.nilIfEmpty } ?? "img"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Unicode.Scalar {
    var isCJK: Bool {
        (0x4E00...0x9FFF).contains(value) ||
            (0x3400...0x4DBF).contains(value) ||
            (0x20000...0x2A6DF).contains(value) ||
            (0x2A700...0x2B73F).contains(value) ||
            (0x2B740...0x2B81F).contains(value) ||
            (0x2B820...0x2CEAF).contains(value) ||
            (0xF900...0xFAFF).contains(value) ||
            (0x2F800...0x2FA1F).contains(value)
    }
}
