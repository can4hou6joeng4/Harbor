import GRDB
@testable import ReaderCore
import XCTest

final class PersistenceTests: XCTestCase {
    func testEmptyDatabaseRunsMigrations() async throws {
        let repository = try GRDBRepository(databaseQueue: DatabaseQueue(), seed: nil)

        let snapshot = try await repository.loadLibrary()

        XCTAssertTrue(snapshot.items.isEmpty)
        XCTAssertTrue(snapshot.tags.isEmpty)
        XCTAssertTrue(snapshot.folders.isEmpty)
        XCTAssertTrue(snapshot.platforms.isEmpty)
    }

    func testMigrationV2AddsCaptureColumnsAndGuidIndex() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator().migrate(dbQueue)

        try dbQueue.read { db in
            let itemColumns = try Set(
                Row.fetchAll(db, sql: "PRAGMA table_info(item)").map { row in
                    row["name"] as String
                }
            )
            XCTAssertTrue(itemColumns.contains("url"))
            XCTAssertTrue(itemColumns.contains("guid"))
            XCTAssertTrue(itemColumns.contains("cover_path"))

            let feedColumns = try Set(
                Row.fetchAll(db, sql: "PRAGMA table_info(feed)").map { row in
                    row["name"] as String
                }
            )
            XCTAssertTrue(feedColumns.contains("last_fetched_at"))
            XCTAssertTrue(feedColumns.contains("etag"))
            XCTAssertTrue(feedColumns.contains("last_modified"))

            let indexSQL = try String.fetchOne(
                db,
                sql: "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = 'item_feed_guid_idx'"
            )
            XCTAssertTrue(indexSQL?.contains("WHERE guid IS NOT NULL") == true)
        }
    }

    func testSeededDatabaseSurvivesReopen() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("reader.sqlite")

        let repository = try GRDBRepository(databaseURL: databaseURL, seed: .sample)
        let seeded = try await repository.loadLibrary()

        let reopenedRepository = try GRDBRepository(databaseURL: databaseURL, seed: nil)
        let reopened = try await reopenedRepository.loadLibrary()

        XCTAssertEqual(seeded.items.count, SampleLibrary.items.count)
        XCTAssertEqual(reopened.items.count, SampleLibrary.items.count)
        XCTAssertEqual(reopened.tags.count, SampleLibrary.tags.count)
        XCTAssertEqual(reopened.folders.count, SampleLibrary.folders.count)
        XCTAssertEqual(reopened.items.first?.title, seeded.items.first?.title)
        XCTAssertEqual(reopened.items.first?.body.first?.text, seeded.items.first?.body.first?.text)
    }

    func testItemHighlightAndTagRoundTrip() async throws {
        let repository = try GRDBRepository(databaseQueue: DatabaseQueue(), seed: metadataOnlySnapshot())
        let itemID = UUID().uuidString
        let highlightID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        var item = makeItem(id: itemID, title: "Round trip persistence", bodyText: "Local storage keeps data nearby.")
        item.url = "https://example.com/round-trip"
        item.guid = "entry-guid"
        item.coverPath = "Attachments/cover.png"
        item.hasCover = true
        item.highlights = [
            Highlight(id: highlightID, quote: "data nearby", note: "important", createdAt: createdAt)
        ]

        try await repository.saveItem(item)
        let snapshot = try await repository.loadLibrary()

        let loaded = try XCTUnwrap(snapshot.items.first { $0.id == itemID })
        XCTAssertEqual(loaded.title, item.title)
        XCTAssertEqual(loaded.url, "https://example.com/round-trip")
        XCTAssertEqual(loaded.guid, "entry-guid")
        XCTAssertEqual(loaded.coverPath, "Attachments/cover.png")
        XCTAssertTrue(loaded.hasCover)
        XCTAssertEqual(loaded.publishedAt.timeIntervalSince1970, item.publishedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loaded.tagIDs, ["t-test"])
        XCTAssertEqual(loaded.body.first?.text, "Local storage keeps data nearby.")
        XCTAssertEqual(loaded.summary.keys, ["key"])
        XCTAssertEqual(loaded.highlights.count, 1)
        XCTAssertEqual(loaded.highlights.first?.id, highlightID)
        XCTAssertEqual(loaded.highlights.first?.note, "important")
        let loadedHighlightTimestamp = try XCTUnwrap(loaded.highlights.first?.createdAt.timeIntervalSince1970)
        XCTAssertEqual(loadedHighlightTimestamp, createdAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testFTSSearchMatchesEnglishAndChineseText() async throws {
        let repository = try GRDBRepository(databaseQueue: DatabaseQueue(), seed: metadataOnlySnapshot())
        let itemID = UUID().uuidString
        let item = makeItem(
            id: itemID,
            title: "Local first archive",
            bodyText: "这是一段关于本地优先和离线阅读的正文。"
        )

        try await repository.saveItem(item)

        let englishMatches = try await repository.search("Local")
        let chineseMatches = try await repository.search("本地优先")
        XCTAssertEqual(englishMatches, [itemID])
        XCTAssertEqual(chineseMatches, [itemID])
    }

    func testChineseFTSPhraseDoesNotMatchDispersedCharacters() async throws {
        let repository = try GRDBRepository(databaseQueue: DatabaseQueue(), seed: metadataOnlySnapshot())
        let exact = makeItem(
            id: "exact-phrase",
            title: "Exact phrase",
            bodyText: "本地优先让资料库在离线状态下仍然可靠。"
        )
        let dispersed = makeItem(
            id: "dispersed-phrase",
            title: "Dispersed phrase",
            bodyText: "本地资料库需要稳定保存,排序时优先显示未读内容。"
        )

        try await repository.saveItem(exact)
        try await repository.saveItem(dispersed)

        let matches = try await repository.search("本地优先")
        XCTAssertEqual(matches, ["exact-phrase"])
    }

    func testDeletingItemCascadesHighlightsAndTags() async throws {
        let dbQueue = try DatabaseQueue()
        let repository = try GRDBRepository(databaseQueue: dbQueue, seed: metadataOnlySnapshot())
        let itemID = UUID().uuidString
        var item = makeItem(id: itemID, title: "Cascade deletion", bodyText: "Cascade indexed text")
        item.highlights = [Highlight(quote: "Cascade indexed text")]

        try await repository.saveItem(item)
        let highlightCountBeforeDelete = try await countRows(in: "highlight", itemID: itemID, dbQueue: dbQueue)
        let itemTagCountBeforeDelete = try await countRows(in: "item_tag", itemID: itemID, dbQueue: dbQueue)
        XCTAssertEqual(highlightCountBeforeDelete, 1)
        XCTAssertEqual(itemTagCountBeforeDelete, 1)

        try await repository.deleteItem(id: itemID)

        let highlightCountAfterDelete = try await countRows(in: "highlight", itemID: itemID, dbQueue: dbQueue)
        let itemTagCountAfterDelete = try await countRows(in: "item_tag", itemID: itemID, dbQueue: dbQueue)
        let searchMatches = try await repository.search("Cascade")
        XCTAssertEqual(highlightCountAfterDelete, 0)
        XCTAssertEqual(itemTagCountAfterDelete, 0)
        XCTAssertTrue(searchMatches.isEmpty)
    }

    private func metadataOnlySnapshot() -> LibrarySnapshot {
        LibrarySnapshot(
            items: [],
            tags: [ReaderTag(id: "t-test", name: "Test", colorHex: "#112233")],
            folders: [ReaderFolder(id: "fo-test", name: "Tests")],
            platforms: [
                PlatformSource(
                    id: "p-rss",
                    name: "RSS",
                    icon: "rss",
                    feeds: [Feed(id: "f-test", name: "Test Feed", monogram: "T", colorHex: "#445566", count: 0)]
                )
            ]
        )
    }

    private func makeItem(id: String, title: String, bodyText: String) -> ReaderItem {
        ReaderItem(
            id: id,
            type: "article",
            kind: .rss,
            source: "Test Feed",
            feedID: "f-test",
            author: "Tester",
            title: title,
            excerpt: "A persisted item",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            readingTime: 4,
            language: "zh",
            tagIDs: ["t-test"],
            folderID: "fo-test",
            isFavorite: true,
            isUnread: false,
            progress: 0.5,
            hue: 120,
            hasCover: false,
            body: [
                ContentBlock(kind: .paragraph, language: "zh", text: bodyText)
            ],
            summary: ReaderSummary(text: ["summary"], keys: ["key"], tagSuggestions: ["tag"])
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderMacAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func countRows(in table: String, itemID: String, dbQueue: DatabaseQueue) async throws -> Int {
        try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table) WHERE item_id = ?", arguments: [itemID]) ?? 0
        }
    }
}
