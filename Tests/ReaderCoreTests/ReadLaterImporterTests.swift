@testable import ReaderCore
import XCTest

final class ReadLaterImporterTests: XCTestCase {
    func testParsesPocketHTMLWithSectionsTagsAndTime() throws {
        let entries = try ReadLaterImporter().parse(fixtureData("pocket", fileExtension: "html"))

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].url, "https://example.com/local-first")
        XCTAssertEqual(entries[0].title, "Local-First Software")
        XCTAssertEqual(entries[0].tags, ["tech", "local-first"])
        XCTAssertFalse(entries[0].isArchived)
        XCTAssertEqual(entries[0].addedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(entries[2].isArchived)   // under the "Read Archive" heading
        XCTAssertEqual(entries[2].title, "An Archived Read")
    }

    func testParsesInstapaperCSVWithQuotedFieldsAndFolders() throws {
        let entries = try ReadLaterImporter().parse(fixtureData("instapaper", fileExtension: "csv"))

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].title, "Article A")
        XCTAssertEqual(entries[1].url, "https://example.com/b")
        XCTAssertEqual(entries[1].title, "Article, B")   // comma inside quotes preserved
        XCTAssertTrue(entries[1].isFavorite)             // Starred
        XCTAssertTrue(entries[2].isArchived)             // Archive
    }

    func testDetectsSourceAndParsesPlainURLList() throws {
        XCTAssertEqual(ReadLaterImporter.detectSource("<!DOCTYPE html><html>..."), .pocket)
        XCTAssertEqual(ReadLaterImporter.detectSource("URL,Title,Folder\nhttps://a,..."), .instapaper)
        XCTAssertEqual(ReadLaterImporter.detectSource("https://a.com\nhttps://b.com"), .urlList)

        let entries = try ReadLaterImporter().parse(string: "https://a.com/x\n  https://b.com/y \n\nnot a url line with spaces")
        XCTAssertEqual(entries.map(\.url), ["https://a.com/x", "https://b.com/y"])
    }

    func testImportReadLaterSavesSummaryOnlyItemsAndSkipsDuplicates() async throws {
        let repository = InMemoryRepository(snapshot: .empty)
        let service = CaptureService(repository: repository)
        let entries = try ReadLaterImporter().parse(fixtureData("pocket", fileExtension: "html"))

        let summary = await service.importReadLater(
            entries,
            existingURLs: ["https://example.com/agents"]   // pretend this one already exists
        )
        let snapshot = try await repository.loadLibrary()

        XCTAssertEqual(summary.total, 3)
        XCTAssertEqual(summary.added, 2)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertTrue(snapshot.items.allSatisfy { $0.isSummaryOnly })
        let archived = snapshot.items.first { $0.url == "https://example.com/old" }
        XCTAssertEqual(archived?.isUnread, false)
        XCTAssertEqual(archived?.progress, 1)
    }

    private func fixtureData(_ name: String, fileExtension: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: fileExtension))
        return try Data(contentsOf: url)
    }
}

private extension ReadLaterImporter {
    func parse(string: String) throws -> [ReadLaterEntry] {
        try parse(Data(string.utf8))
    }
}
