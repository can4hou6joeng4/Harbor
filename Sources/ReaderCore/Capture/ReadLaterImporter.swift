import Foundation
import SwiftSoup

/// A single saved article parsed from a read-later export (Pocket, Instapaper, …).
public struct ReadLaterEntry: Hashable, Sendable {
    public let url: String
    public let title: String?
    public let tags: [String]
    public let addedAt: Date?
    public let isArchived: Bool
    public let isFavorite: Bool

    public init(
        url: String,
        title: String? = nil,
        tags: [String] = [],
        addedAt: Date? = nil,
        isArchived: Bool = false,
        isFavorite: Bool = false
    ) {
        self.url = url
        self.title = title
        self.tags = tags
        self.addedAt = addedAt
        self.isArchived = isArchived
        self.isFavorite = isFavorite
    }
}

public enum ReadLaterSource: String, Sendable, CaseIterable {
    case pocket
    case instapaper
    case urlList
}

public struct ReadLaterImportSummary: Hashable, Sendable {
    public var total: Int
    public var added: Int
    public var skipped: Int
    public var failed: Int

    public init(total: Int = 0, added: Int = 0, skipped: Int = 0, failed: Int = 0) {
        self.total = total
        self.added = added
        self.skipped = skipped
        self.failed = failed
    }
}

public enum ReadLaterImportError: LocalizedError, Sendable {
    case invalidData
    case noEntries

    public var errorDescription: String? {
        switch self {
        case .invalidData: return "无法读取导入文件"
        case .noEntries: return "没有在文件里找到可导入的链接"
        }
    }
}

/// Parses read-later exports into a common `ReadLaterEntry` list.
///
/// Supports Pocket (`ril_export.html`), Instapaper (CSV), and a plain
/// one-URL-per-line list as a catch-all. Auto-detects the format when not given.
public struct ReadLaterImporter {
    public init() {}

    public func parse(_ data: Data, source: ReadLaterSource? = nil) throws -> [ReadLaterEntry] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ReadLaterImportError.invalidData
        }
        let resolved = source ?? Self.detectSource(text)
        switch resolved {
        case .pocket: return try Self.parsePocket(text)
        case .instapaper: return Self.parseInstapaper(text)
        case .urlList: return Self.parseURLList(text)
        }
    }

    static func detectSource(_ text: String) -> ReadLaterSource {
        let head = text.prefix(2000).lowercased()
        if head.contains("<!doctype html") || head.contains("<html") || head.contains("time_added=") {
            return .pocket
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init)?.lowercased() ?? ""
        if firstLine.contains("url") && firstLine.contains(",") && (firstLine.contains("title") || firstLine.contains("folder")) {
            return .instapaper
        }
        return .urlList
    }

    // MARK: - Pocket

    static func parsePocket(_ html: String) throws -> [ReadLaterEntry] {
        let doc = try SwiftSoup.parse(html)
        var entries: [ReadLaterEntry] = []
        var archivedSection = false

        for element in try doc.getAllElements().array() {
            let tag = element.tagName().lowercased()
            if tag == "h1" {
                let label = (try? element.text())?.lowercased() ?? ""
                archivedSection = label.contains("archive")
            } else if tag == "a", let href = try? element.attr("href"), !href.isEmpty {
                let title = (try? element.text())?.trimmingCharacters(in: .whitespacesAndNewlines)
                let tagsAttr = (try? element.attr("tags")) ?? ""
                let tags = tagsAttr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let addedAt = (try? element.attr("time_added")).flatMap(Self.date(fromUnix:))
                entries.append(ReadLaterEntry(
                    url: href,
                    title: title?.isEmpty == false ? title : nil,
                    tags: tags,
                    addedAt: addedAt,
                    isArchived: archivedSection
                ))
            }
        }
        return entries
    }

    // MARK: - Instapaper

    static func parseInstapaper(_ csv: String) -> [ReadLaterEntry] {
        let rows = parseCSV(csv)
        guard rows.count > 1 else { return [] }
        let header = rows[0].map { $0.lowercased() }
        let urlIdx = header.firstIndex(of: "url") ?? 0
        let titleIdx = header.firstIndex(of: "title")
        let folderIdx = header.firstIndex(of: "folder")
        let timeIdx = header.firstIndex { $0.contains("time") || $0.contains("date") }

        var entries: [ReadLaterEntry] = []
        for row in rows.dropFirst() {
            guard urlIdx < row.count else { continue }
            let url = row[urlIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { continue }
            let title = titleIdx.flatMap { $0 < row.count ? row[$0] : nil }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let folder = (folderIdx.flatMap { $0 < row.count ? row[$0] : nil } ?? "").lowercased()
            let addedAt = timeIdx.flatMap { $0 < row.count ? Self.date(fromUnix: row[$0]) : nil }
            entries.append(ReadLaterEntry(
                url: url,
                title: title?.isEmpty == false ? title : nil,
                addedAt: addedAt,
                isArchived: folder == "archive",
                isFavorite: folder == "starred"
            ))
        }
        return entries
    }

    // MARK: - Plain URL list

    static func parseURLList(_ text: String) -> [ReadLaterEntry] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("://") || ($0.contains(".") && !$0.contains(" ")) }
            .map { ReadLaterEntry(url: $0) }
    }

    // MARK: - Helpers

    private static func date(fromUnix raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let seconds = TimeInterval(trimmed), seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// Minimal RFC4180-ish CSV parser (handles quoted fields, escaped quotes, embedded newlines).
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        let scalars = Array(text)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n", "\r":
                    if c == "\r", i + 1 < scalars.count, scalars[i + 1] == "\n" { i += 1 }
                    row.append(field); field = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
