import FeedKit
import Foundation
import NaturalLanguage

public struct FeedSyncResult: Hashable, Sendable {
    public var feedID: String
    public var insertedCount: Int
    public var skippedCount: Int
    public var notModified: Bool
    public var errorMessage: String?

    public init(
        feedID: String,
        insertedCount: Int = 0,
        skippedCount: Int = 0,
        notModified: Bool = false,
        errorMessage: String? = nil
    ) {
        self.feedID = feedID
        self.insertedCount = insertedCount
        self.skippedCount = skippedCount
        self.notModified = notModified
        self.errorMessage = errorMessage
    }
}

public struct FeedSyncSummary: Hashable, Sendable {
    public var results: [FeedSyncResult]

    public init(results: [FeedSyncResult]) {
        self.results = results
    }

    public var insertedCount: Int {
        results.reduce(0) { $0 + $1.insertedCount }
    }

    public var failureCount: Int {
        results.filter { $0.errorMessage != nil }.count
    }
}

public enum FeedSyncError: LocalizedError, Sendable {
    case invalidFeedURL
    case feedURLMissing
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "RSS URL 无效"
        case .feedURLMissing:
            return "订阅源缺少 URL"
        case let .parseFailed(message):
            return "订阅源解析失败: \(message)"
        }
    }
}

public final class FeedSyncService: @unchecked Sendable {
    private let repository: any ReaderRepository
    private let httpClient: any HTTPClient
    private let extractor: any ContentExtractor
    private let now: @Sendable () -> Date
    private let concurrencyLimit: Int

    public init(
        repository: any ReaderRepository,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        extractor: any ContentExtractor = SwiftSoupExtractor(minimumBodyLength: 1),
        concurrencyLimit: Int = 4,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.httpClient = httpClient
        self.extractor = extractor
        self.concurrencyLimit = concurrencyLimit
        self.now = now
    }

    public func addFeed(urlString: String) async throws -> Feed {
        let url = try Self.normalizedURL(from: urlString)
        let response = try await fetchFeed(url: url, feed: nil)
        let parsed = try parse(response.data)
        let feed = Self.makeFeed(url: url, title: feedTitle(parsed))
        try await repository.saveFeed(feed, platformID: "p-rss")
        return feed
    }

    /// Imports an OPML subscription export: parses feeds, skips duplicates (by feed id),
    /// saves the new ones, then syncs them to pull their latest articles.
    public func importOPML(_ data: Data, existingFeedIDs: Set<String>) async throws -> OPMLImportSummary {
        let entries = try OPMLImporter().parse(data)
        guard !entries.isEmpty else { throw OPMLImportError.noFeeds }

        var newFeeds: [Feed] = []
        var seen = Set<String>()
        var skipped = 0
        var failed = 0
        for entry in entries {
            guard let url = try? Self.normalizedURL(from: entry.xmlURL) else { failed += 1; continue }
            let id = Self.feedID(for: url)
            if existingFeedIDs.contains(id) || seen.contains(id) { skipped += 1; continue }
            seen.insert(id)
            newFeeds.append(Self.makeFeed(url: url, title: entry.title))
        }

        for feed in newFeeds {
            do { try await repository.saveFeed(feed, platformID: "p-rss") } catch { failed += 1 }
        }

        let sync = await syncAll(feeds: newFeeds)
        return OPMLImportSummary(
            total: entries.count,
            added: newFeeds.count,
            skipped: skipped,
            failed: failed,
            insertedItems: sync.insertedCount
        )
    }

    public func syncAll(feeds: [Feed]) async -> FeedSyncSummary {
        let syncableFeeds = feeds.filter { $0.url?.isEmpty == false }
        guard !syncableFeeds.isEmpty else {
            return FeedSyncSummary(results: [])
        }

        var iterator = syncableFeeds.makeIterator()
        var inFlight = 0
        var results: [FeedSyncResult] = []

        await withTaskGroup(of: FeedSyncResult.self) { group in
            func enqueueNext() {
                guard inFlight < concurrencyLimit, let feed = iterator.next() else { return }
                inFlight += 1
                group.addTask { [self] in
                    await sync(feed: feed)
                }
            }

            for _ in 0..<concurrencyLimit {
                enqueueNext()
            }

            while let result = await group.next() {
                inFlight -= 1
                results.append(result)
                enqueueNext()
            }
        }

        return FeedSyncSummary(results: results)
    }

    public func sync(feed: Feed) async -> FeedSyncResult {
        do {
            let url = try feedURL(feed)
            let response = try await fetchFeed(url: url, feed: feed)
            let fetchedAt = now()

            if response.statusCode == 304 {
                try await repository.updateFeedMetadata(
                    id: feed.id,
                    lastFetchedAt: fetchedAt,
                    etag: feed.etag,
                    lastModified: feed.lastModified
                )
                return FeedSyncResult(feedID: feed.id, notModified: true)
            }

            let parsed = try parse(response.data)
            let candidates = entries(in: parsed, feed: feed, feedURL: url)
            var inserted = 0
            var skipped = 0

            for candidate in candidates {
                let guid = candidate.guid
                if try await repository.containsItem(feedID: feed.id, guid: guid) {
                    skipped += 1
                    continue
                }

                try await repository.saveItem(item(from: candidate, feed: feed))
                inserted += 1
            }

            try await repository.updateFeedMetadata(
                id: feed.id,
                lastFetchedAt: fetchedAt,
                etag: response.header("etag") ?? feed.etag,
                lastModified: response.header("last-modified") ?? feed.lastModified
            )
            return FeedSyncResult(feedID: feed.id, insertedCount: inserted, skippedCount: skipped)
        } catch {
            return FeedSyncResult(feedID: feed.id, errorMessage: error.localizedDescription)
        }
    }

    private func fetchFeed(url: URL, feed: Feed?) async throws -> CaptureResponse {
        var headers = [
            "Accept": "application/rss+xml, application/atom+xml, application/feed+json, application/json, text/xml, application/xml"
        ]
        if let etag = feed?.etag {
            headers["If-None-Match"] = etag
        }
        if let lastModified = feed?.lastModified {
            headers["If-Modified-Since"] = lastModified
        }
        return try await httpClient.fetch(CaptureRequest(url: url, headers: headers))
    }

    private func parse(_ data: Data) throws -> FeedKit.Feed {
        let result = FeedParser(data: data).parse()
        switch result {
        case let .success(feed):
            return feed
        case let .failure(error):
            throw FeedSyncError.parseFailed(error.localizedDescription)
        }
    }

    private func entries(in parsed: FeedKit.Feed, feed: Feed, feedURL: URL) -> [ParsedFeedEntry] {
        switch parsed {
        case let .rss(rss):
            return (rss.items ?? []).compactMap { item in
                let title = item.title?.nilIfBlank ?? "未命名条目"
                let link = item.link?.nilIfBlank
                return makeEntry(
                    title: title,
                    link: link,
                    guidSeed: item.guid?.value?.nilIfBlank,
                    publishedAt: item.pubDate,
                    author: item.author?.nilIfBlank ?? rss.title?.nilIfBlank ?? feed.name,
                    html: item.content?.contentEncoded?.nilIfBlank ?? item.description?.nilIfBlank,
                    feed: feed,
                    feedURL: feedURL
                )
            }
        case let .atom(atom):
            return (atom.entries ?? []).compactMap { entry in
                let title = entry.title?.nilIfBlank ?? "未命名条目"
                let link = entry.links?.first { ($0.attributes?.rel ?? "alternate") == "alternate" }?.attributes?.href?.nilIfBlank
                    ?? entry.links?.first?.attributes?.href?.nilIfBlank
                return makeEntry(
                    title: title,
                    link: link,
                    guidSeed: entry.id?.nilIfBlank,
                    publishedAt: entry.published ?? entry.updated,
                    author: entry.authors?.first?.name?.nilIfBlank ?? atom.authors?.first?.name?.nilIfBlank ?? feed.name,
                    html: entry.content?.value?.nilIfBlank ?? entry.summary?.value?.nilIfBlank,
                    feed: feed,
                    feedURL: feedURL
                )
            }
        case let .json(json):
            return (json.items ?? []).compactMap { item in
                let title = item.title?.nilIfBlank ?? item.summary?.nilIfBlank ?? "未命名条目"
                let link = item.url?.nilIfBlank ?? item.externalUrl?.nilIfBlank
                return makeEntry(
                    title: title,
                    link: link,
                    guidSeed: item.id?.nilIfBlank,
                    publishedAt: item.datePublished ?? item.dateModified,
                    author: item.author?.name?.nilIfBlank ?? json.author?.name?.nilIfBlank ?? feed.name,
                    html: item.contentHtml?.nilIfBlank ?? item.contentText?.nilIfBlank ?? item.summary?.nilIfBlank,
                    feed: feed,
                    feedURL: feedURL
                )
            }
        }
    }

    private func makeEntry(
        title: String,
        link: String?,
        guidSeed: String?,
        publishedAt: Date?,
        author: String,
        html: String?,
        feed: Feed,
        feedURL: URL
    ) -> ParsedFeedEntry? {
        let entryURL = link.flatMap { URL(string: $0, relativeTo: feedURL)?.absoluteURL }
        let date = publishedAt ?? now()
        let guid = guidSeed ?? entryURL?.absoluteString ?? Self.stableHash("\(title)-\(date.timeIntervalSince1970)")
        let content = html?.nilIfBlank ?? title

        return ParsedFeedEntry(
            title: title,
            url: entryURL,
            guid: guid,
            publishedAt: date,
            author: author,
            html: content
        )
    }

    private func item(from entry: ParsedFeedEntry, feed: Feed) throws -> ReaderItem {
        let extraction = try extract(entry)
        let isSummaryOnly = extraction.text.count < 200
        let language = Self.detectLanguage(in: extraction.text)
        let body = extraction.blocks.map { block in
            var copy = block
            copy.language = language
            return copy
        }

        return ReaderItem(
            id: UUID().uuidString,
            type: "rss",
            kind: .rss,
            source: feed.name,
            url: entry.url?.absoluteString,
            guid: entry.guid,
            feedID: feed.id,
            author: entry.author,
            title: entry.title,
            excerpt: extraction.excerpt,
            publishedAt: entry.publishedAt,
            readingTime: max(1, Int(ceil(Double(extraction.text.count) / 500.0))),
            language: language,
            tagIDs: [],
            folderID: "",
            isFavorite: false,
            isUnread: true,
            progress: 0,
            hue: Self.hue(for: "\(feed.id)-\(entry.guid)"),
            hasCover: false,
            body: body,
            summary: ReaderSummary(
                text: [extraction.excerpt],
                keys: isSummaryOnly ? [ReaderSummary.summaryOnlyMarker] : [],
                tagSuggestions: []
            )
        )
    }

    private func extract(_ entry: ParsedFeedEntry) throws -> ExtractedContent {
        let bodyHTML = entry.html.contains("<") ? entry.html : "<p>\(Self.escapedHTML(entry.html))</p>"
        let html = """
        <!doctype html>
        <html>
        <head><title>\(Self.escapedHTML(entry.title))</title></head>
        <body><article>\(bodyHTML)</article></body>
        </html>
        """
        let sourceURL = entry.url ?? URL(string: "https://feed.local/\(entry.guid)")!
        return try extractor.extract(html: html, sourceURL: sourceURL)
    }

    public static func normalizedURL(from raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FeedSyncError.invalidFeedURL }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            throw FeedSyncError.invalidFeedURL
        }
        return url
    }

    private func feedURL(_ feed: Feed) throws -> URL {
        guard let urlString = feed.url else { throw FeedSyncError.feedURLMissing }
        return try Self.normalizedURL(from: urlString)
    }

    private func feedTitle(_ parsed: FeedKit.Feed) -> String? {
        switch parsed {
        case let .rss(feed):
            return feed.title?.nilIfBlank
        case let .atom(feed):
            return feed.title?.nilIfBlank
        case let .json(feed):
            return feed.title?.nilIfBlank
        }
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

    private static func hue(for value: String) -> Double {
        let hash = abs(value.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        return Double(hash % 360)
    }

    private static func domain(from url: URL) -> String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? "RSS"
    }

    /// Stable, deterministic feed id derived from the feed URL — shared by `addFeed`
    /// and `importOPML` so the same URL always maps to the same id (dedup-safe).
    public static func feedID(for url: URL) -> String {
        "f-\(stableHash(url.absoluteString))"
    }

    /// Builds a `Feed` from a URL + optional title without fetching the network.
    public static func makeFeed(url: URL, title: String?) -> Feed {
        let name = title?.nilIfBlank ?? domain(from: url)
        return Feed(
            id: feedID(for: url),
            name: name,
            monogram: String(name.prefix(1)).uppercased(),
            colorHex: "#E0533D",
            count: 0,
            url: url.absoluteString,
            lastFetchedAt: nil,
            etag: nil,
            lastModified: nil
        )
    }

    private static func stableHash(_ value: String) -> String {
        let basis: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        let hash = value.utf8.reduce(basis) { ($0 ^ UInt64($1)) &* prime }
        return String(hash, radix: 16)
    }

    private static func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct ParsedFeedEntry {
    var title: String
    var url: URL?
    var guid: String
    var publishedAt: Date
    var author: String
    var html: String
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
