import Foundation
import GRDB

public enum PersistenceError: Error, Sendable {
    case invalidJSONString
    case invalidHighlightID(String)
    case missingItemRowID(String)
}

public final class GRDBRepository: ReaderRepository, @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let workQueue: DispatchQueue

    public convenience init(seed: LibrarySnapshot? = .sample, fileManager: FileManager = .default) throws {
        try self.init(databaseURL: Self.defaultDatabaseURL(fileManager: fileManager), seed: seed)
    }

    public convenience init(databaseURL: URL, seed: LibrarySnapshot? = .sample) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent().appendingPathComponent("Attachments", isDirectory: true),
            withIntermediateDirectories: true
        )

        let dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: Self.configuration())
        try self.init(databaseQueue: dbQueue, seed: seed, enableWAL: true)
    }

    public init(databaseQueue: DatabaseQueue, seed: LibrarySnapshot? = .sample, enableWAL: Bool = false) throws {
        self.dbQueue = databaseQueue
        self.workQueue = DispatchQueue(label: "ReaderMacApp.GRDBRepository")

        if enableWAL {
            try dbQueue.writeWithoutTransaction { db in
                _ = try String.fetchOne(db, sql: "PRAGMA journal_mode = WAL")
            }
        }

        try Migrations.migrator().migrate(dbQueue)

        if let seed {
            try dbQueue.write { db in
                try Self.seedIfNeeded(seed, in: db)
            }
        }
    }

    public static func defaultDatabaseURL(fileManager: FileManager = .default) throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ReaderMacApp", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("reader.sqlite")
    }

    public func loadLibrary() async throws -> LibrarySnapshot {
        try await read { db in
            try Self.fetchSnapshot(in: db)
        }
    }

    public func saveItem(_ item: ReaderItem) async throws {
        try await write { db in
            try Self.saveItem(item, in: db)
        }
    }

    public func deleteItem(id: String) async throws {
        try await write { db in
            if let payload = try Self.ftsPayloadForExistingItem(id: id, in: db) {
                try Self.deleteFTS(payload, in: db)
            }
            try db.execute(sql: "DELETE FROM item WHERE id = ?", arguments: [id])
        }
    }

    public func setItemFlags(id: String, isUnread: Bool?, isFavorite: Bool?) async throws {
        try await write { db in
            if let isUnread {
                try db.execute(sql: "UPDATE item SET is_unread = ? WHERE id = ?", arguments: [isUnread, id])
            }
            if let isFavorite {
                try db.execute(sql: "UPDATE item SET is_favorite = ? WHERE id = ?", arguments: [isFavorite, id])
            }
        }
    }

    public func saveHighlights(itemID: String, _ highlights: [Highlight]) async throws {
        try await write { db in
            try Self.replaceHighlights(highlights, itemID: itemID, in: db)
        }
    }

    public func saveReadingState(itemID: String, progress: Double, offset: Double) async throws {
        try await write { db in
            try db.execute(
                sql: "UPDATE item SET progress = ?, reading_offset = ? WHERE id = ?",
                arguments: [min(max(progress, 0), 1), max(0, offset), itemID]
            )
        }
    }

    public func search(_ query: String) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let ftsQuery = Self.ftsQuery(trimmed)

        return try await read { db in
            try String.fetchAll(
                db,
                sql: """
                SELECT item.id
                FROM item_fts
                JOIN item ON item.rowid = item_fts.rowid
                WHERE item_fts MATCH ?
                ORDER BY item.published_at DESC
                """,
                arguments: [ftsQuery]
            )
        }
    }

    private static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }

    private func read<T: Sendable>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            workQueue.async {
                do {
                    continuation.resume(returning: try self.dbQueue.read(block))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func write<T: Sendable>(_ block: @escaping @Sendable (Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            workQueue.async {
                do {
                    continuation.resume(returning: try self.dbQueue.write(block))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension GRDBRepository {
    struct FTSPayload {
        var rowID: Int64
        var title: String
        var excerpt: String
        var bodyText: String
    }

    struct FolderRow {
        var id: String
        var name: String
        var parentID: String?
        var sortOrder: Int
    }

    static func seedIfNeeded(_ snapshot: LibrarySnapshot, in db: Database) throws {
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item") ?? 0
        guard count == 0 else { return }

        try saveTags(snapshot.tags, in: db)
        try saveFolders(snapshot.folders, in: db)
        try saveFeeds(snapshot.platforms, in: db)

        for item in snapshot.items {
            try saveItem(item, in: db)
            if let offset = snapshot.readingOffsets[item.id] {
                try db.execute(
                    sql: "UPDATE item SET reading_offset = ? WHERE id = ?",
                    arguments: [max(0, offset), item.id]
                )
            }
        }
    }

    static func fetchSnapshot(in db: Database) throws -> LibrarySnapshot {
        let itemTagRows = try Row.fetchAll(db, sql: "SELECT item_id, tag_id FROM item_tag")
        var tagIDsByItem: [String: [String]] = [:]
        for row in itemTagRows {
            let itemID: String = row["item_id"]
            let tagID: String = row["tag_id"]
            tagIDsByItem[itemID, default: []].append(tagID)
        }

        let highlightRows = try Row.fetchAll(
            db,
            sql: "SELECT id, item_id, quote, note, created_at FROM highlight ORDER BY created_at ASC"
        )
        var highlightsByItem: [String: [Highlight]] = [:]
        for row in highlightRows {
            let idString: String = row["id"]
            guard let id = UUID(uuidString: idString) else {
                throw PersistenceError.invalidHighlightID(idString)
            }
            let itemID: String = row["item_id"]
            let createdAt: Double = row["created_at"]
            highlightsByItem[itemID, default: []].append(
                Highlight(
                    id: id,
                    quote: row["quote"],
                    note: row["note"],
                    createdAt: Date(timeIntervalSince1970: createdAt)
                )
            )
        }

        let itemRows = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY published_at DESC")
        var items: [ReaderItem] = []
        var readingOffsets: [String: Double] = [:]
        for row in itemRows {
            let id: String = row["id"]
            let kind = ReaderKind(rawValue: row["kind"]) ?? .web
            let publishedAt: Double = row["published_at"]
            let bodyJSON: String = row["body_json"]
            let summaryJSON: String? = row["summary_json"]
            let body = try decode([ContentBlock].self, from: bodyJSON)
            let summary = try summaryJSON.map { try decode(ReaderSummary.self, from: $0) } ?? ReaderSummary(
                text: [],
                keys: [],
                tagSuggestions: []
            )

            readingOffsets[id] = row["reading_offset"] as Double
            items.append(
                ReaderItem(
                    id: id,
                    type: legacyType(for: kind),
                    kind: kind,
                    source: row["source"],
                    feedID: row["feed_id"],
                    author: row["author"],
                    title: row["title"],
                    excerpt: row["excerpt"],
                    publishedAt: Date(timeIntervalSince1970: publishedAt),
                    readingTime: row["reading_time"],
                    duration: row["duration"],
                    language: row["language"],
                    tagIDs: tagIDsByItem[id] ?? [],
                    folderID: row["folder_id"] ?? "",
                    isFavorite: row["is_favorite"] as Bool,
                    isUnread: row["is_unread"] as Bool,
                    progress: row["progress"],
                    hue: row["hue"],
                    hasCover: row["has_cover"] as Bool,
                    attachmentPath: row["attachment_path"],
                    body: body,
                    highlights: highlightsByItem[id] ?? [],
                    summary: summary
                )
            )
        }

        let tags = try ReaderTag.fetchAllFromDatabase(db)
        let folders = try fetchFolders(items: items, in: db)
        let platforms = try fetchPlatforms(items: items, in: db)
        return LibrarySnapshot(
            items: items,
            tags: tags,
            folders: folders,
            platforms: platforms,
            readingOffsets: readingOffsets
        )
    }

    static func saveItem(_ item: ReaderItem, in db: Database) throws {
        if let payload = try ftsPayloadForExistingItem(id: item.id, in: db) {
            try deleteFTS(payload, in: db)
        }

        let bodyJSON = try encode(item.body)
        let summaryJSON = try encode(item.summary)

        try db.execute(
            sql: """
            INSERT INTO item (
              id, kind, source, feed_id, author, title, excerpt, published_at,
              reading_time, duration, language, folder_id, is_favorite, is_unread,
              progress, hue, has_cover, attachment_path, body_json, summary_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              kind = excluded.kind,
              source = excluded.source,
              feed_id = excluded.feed_id,
              author = excluded.author,
              title = excluded.title,
              excerpt = excluded.excerpt,
              published_at = excluded.published_at,
              reading_time = excluded.reading_time,
              duration = excluded.duration,
              language = excluded.language,
              folder_id = excluded.folder_id,
              is_favorite = excluded.is_favorite,
              is_unread = excluded.is_unread,
              progress = excluded.progress,
              hue = excluded.hue,
              has_cover = excluded.has_cover,
              attachment_path = excluded.attachment_path,
              body_json = excluded.body_json,
              summary_json = excluded.summary_json
            """,
            arguments: [
                item.id,
                item.kind.rawValue,
                item.source,
                nilIfEmpty(item.feedID),
                item.author,
                item.title,
                item.excerpt,
                item.publishedAt.timeIntervalSince1970,
                item.readingTime,
                item.duration,
                item.language,
                nilIfEmpty(item.folderID),
                item.isFavorite,
                item.isUnread,
                item.progress,
                item.hue,
                item.hasCover,
                item.attachmentPath,
                bodyJSON,
                summaryJSON
            ]
        )

        try replaceItemTags(item.tagIDs, itemID: item.id, in: db)
        try replaceHighlights(item.highlights, itemID: item.id, in: db)

        guard let rowID = try Int64.fetchOne(db, sql: "SELECT rowid FROM item WHERE id = ?", arguments: [item.id]) else {
            throw PersistenceError.missingItemRowID(item.id)
        }
        try insertFTS(FTSPayload(rowID: rowID, title: item.title, excerpt: item.excerpt, bodyText: bodyText(for: item.body)), in: db)
    }

    static func replaceItemTags(_ tagIDs: [String], itemID: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM item_tag WHERE item_id = ?", arguments: [itemID])
        for tagID in tagIDs {
            try db.execute(
                sql: "INSERT OR IGNORE INTO item_tag (item_id, tag_id) VALUES (?, ?)",
                arguments: [itemID, tagID]
            )
        }
    }

    static func replaceHighlights(_ highlights: [Highlight], itemID: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM highlight WHERE item_id = ?", arguments: [itemID])
        for highlight in highlights {
            try db.execute(
                sql: """
                INSERT INTO highlight (id, item_id, quote, note, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    highlight.id.uuidString,
                    itemID,
                    highlight.quote,
                    highlight.note,
                    highlight.createdAt.timeIntervalSince1970
                ]
            )
        }
    }

    static func saveTags(_ tags: [ReaderTag], in db: Database) throws {
        for tag in tags {
            try db.execute(
                sql: """
                INSERT INTO tag (id, name, color_hex)
                VALUES (?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  name = excluded.name,
                  color_hex = excluded.color_hex
                """,
                arguments: [tag.id, tag.name, tag.colorHex]
            )
        }
    }

    static func saveFolders(_ folders: [ReaderFolder], in db: Database) throws {
        for (index, folder) in folders.enumerated() {
            try saveFolder(folder, parentID: nil, sortOrder: index, in: db)
        }
    }

    static func saveFolder(_ folder: ReaderFolder, parentID: String?, sortOrder: Int, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO folder (id, name, parent_id, sort_order)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              parent_id = excluded.parent_id,
              sort_order = excluded.sort_order
            """,
            arguments: [folder.id, folder.name, parentID, sortOrder]
        )

        for (index, child) in folder.children.enumerated() {
            try saveFolder(child, parentID: folder.id, sortOrder: index, in: db)
        }
    }

    static func saveFeeds(_ platforms: [PlatformSource], in db: Database) throws {
        for platform in platforms {
            let platformKind = databasePlatform(for: platform.id)
            for feed in platform.feeds {
                try db.execute(
                    sql: """
                    INSERT INTO feed (id, platform, name, monogram, color_hex, is_enabled, url)
                    VALUES (?, ?, ?, ?, ?, 1, NULL)
                    ON CONFLICT(id) DO UPDATE SET
                      platform = excluded.platform,
                      name = excluded.name,
                      monogram = excluded.monogram,
                      color_hex = excluded.color_hex,
                      is_enabled = excluded.is_enabled,
                      url = excluded.url
                    """,
                    arguments: [feed.id, platformKind, feed.name, feed.monogram, feed.colorHex]
                )
            }
        }
    }

    static func ftsPayloadForExistingItem(id: String, in db: Database) throws -> FTSPayload? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT rowid, title, excerpt, body_json FROM item WHERE id = ?",
            arguments: [id]
        ) else {
            return nil
        }

        let bodyJSON: String = row["body_json"]
        let body = try decode([ContentBlock].self, from: bodyJSON)
        return FTSPayload(
            rowID: row["rowid"],
            title: row["title"],
            excerpt: row["excerpt"],
            bodyText: bodyText(for: body)
        )
    }

    static func insertFTS(_ payload: FTSPayload, in db: Database) throws {
        try db.execute(
            sql: "INSERT INTO item_fts (rowid, title, excerpt, body_text) VALUES (?, ?, ?, ?)",
            arguments: [payload.rowID, ftsText(payload.title), ftsText(payload.excerpt), ftsText(payload.bodyText)]
        )
    }

    static func deleteFTS(_ payload: FTSPayload, in db: Database) throws {
        try db.execute(
            sql: "INSERT INTO item_fts (item_fts, rowid, title, excerpt, body_text) VALUES ('delete', ?, ?, ?, ?)",
            arguments: [payload.rowID, ftsText(payload.title), ftsText(payload.excerpt), ftsText(payload.bodyText)]
        )
    }

    static func fetchFolders(items: [ReaderItem], in db: Database) throws -> [ReaderFolder] {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT id, name, parent_id, sort_order FROM folder ORDER BY sort_order ASC, name ASC"
        )
        let folderRows = rows.map {
            FolderRow(
                id: $0["id"],
                name: $0["name"],
                parentID: $0["parent_id"],
                sortOrder: $0["sort_order"]
            )
        }
        let childrenByParent = Dictionary(grouping: folderRows.filter { $0.parentID != nil }) { $0.parentID ?? "" }
        let rowsByID = Dictionary(uniqueKeysWithValues: folderRows.map { ($0.id, $0) })
        let directCounts = Dictionary(grouping: items, by: \.folderID).mapValues(\.count)

        func makeFolder(_ row: FolderRow) -> ReaderFolder {
            let children = (childrenByParent[row.id] ?? [])
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                    return lhs.name < rhs.name
                }
                .map(makeFolder)
            return ReaderFolder(
                id: row.id,
                name: row.name,
                count: (directCounts[row.id] ?? 0) + children.reduce(0) { $0 + $1.count },
                children: children
            )
        }

        return folderRows
            .filter { row in row.parentID == nil || rowsByID[row.parentID ?? ""] == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name < rhs.name
            }
            .map(makeFolder)
    }

    static func fetchPlatforms(items: [ReaderItem], in db: Database) throws -> [PlatformSource] {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT id, platform, name, monogram, color_hex FROM feed WHERE is_enabled = 1 ORDER BY name ASC"
        )
        let countsByFeedID = Dictionary(grouping: items.compactMap(\.feedID)) { $0 }.mapValues(\.count)
        let feedsByPlatform = Dictionary(grouping: rows) { row in row["platform"] as String }

        return platformOrder.compactMap { platform in
            guard let rows = feedsByPlatform[platform.kind], !rows.isEmpty else { return nil }
            let feeds = rows.map { row in
                Feed(
                    id: row["id"],
                    name: row["name"],
                    monogram: row["monogram"],
                    colorHex: row["color_hex"],
                    count: countsByFeedID[row["id"] as String] ?? 0
                )
            }
            return PlatformSource(id: platform.id, name: platform.name, icon: platform.icon, feeds: feeds)
        }
    }

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.invalidJSONString
        }
        return string
    }

    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static func bodyText(for body: [ContentBlock]) -> String {
        body.map { block in
            [block.text, block.translation, block.caption ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        .joined(separator: "\n")
    }

    static func ftsText(_ text: String) -> String {
        var output = ""
        output.reserveCapacity(text.count * 2)

        for scalar in text.unicodeScalars {
            if scalar.isCJK {
                output.append(" ")
                output.unicodeScalars.append(scalar)
                output.append(" ")
            } else {
                output.unicodeScalars.append(scalar)
            }
        }

        return output
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func ftsQuery(_ query: String) -> String {
        ftsText(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                "\"\(token.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            .joined(separator: " ")
    }

    static func legacyType(for kind: ReaderKind) -> String {
        switch kind {
        case .web:
            return "article"
        case .markdown:
            return "note"
        default:
            return kind.rawValue
        }
    }

    static func nilIfEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func databasePlatform(for platformID: String) -> String {
        switch platformID {
        case "p-yt":
            return "youtube"
        case let id where id.hasPrefix("p-"):
            return String(id.dropFirst(2))
        default:
            return platformID
        }
    }

    static let platformOrder: [(kind: String, id: String, name: String, icon: String)] = [
        ("rss", "p-rss", "RSS", "rss"),
        ("x", "p-x", "X", "x"),
        ("weibo", "p-weibo", "微博", "weibo"),
        ("youtube", "p-yt", "YouTube", "youtube")
    ]
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

private extension ReaderTag {
    static func fetchAllFromDatabase(_ db: Database) throws -> [ReaderTag] {
        let rows = try Row.fetchAll(db, sql: "SELECT id, name, color_hex FROM tag ORDER BY name ASC")
        return rows.map {
            ReaderTag(id: $0["id"], name: $0["name"], colorHex: $0["color_hex"])
        }
    }
}
