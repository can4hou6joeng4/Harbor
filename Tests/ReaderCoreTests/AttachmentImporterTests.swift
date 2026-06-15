import AppKit
import GRDB
@testable import ReaderCore
import XCTest

final class AttachmentImporterTests: XCTestCase {
    func testPDFImportPersistsAndIndexesExtractedText() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let pdfURL = rootDirectory.appendingPathComponent("source.pdf")
        try writeSearchablePDF(
            at: pdfURL,
            text: "Searchable attachment phrase lives inside this generated PDF page."
        )

        let importer = AttachmentImporter(rootDirectory: rootDirectory)
        let item = try await importer.importFile(at: pdfURL, tagIDs: ["t-test"], folderID: "fo-test")
        let repository = try GRDBRepository(
            databaseURL: rootDirectory.appendingPathComponent("reader.sqlite"),
            seed: metadataOnlySnapshot()
        )
        try await repository.saveItem(item)

        let matches = try await repository.search("Searchable attachment phrase")
        XCTAssertEqual(matches, [item.id])
        XCTAssertEqual(item.kind, .pdf)
        XCTAssertEqual(item.attachmentPath?.hasPrefix("Attachments/"), true)
        XCTAssertEqual(item.coverPath?.hasPrefix("Attachments/"), true)
        XCTAssertTrue(item.body.first?.text.contains("Searchable attachment phrase") == true)

        let reopenedRepository = try GRDBRepository(
            databaseURL: rootDirectory.appendingPathComponent("reader.sqlite"),
            seed: nil
        )
        let reopened = try await reopenedRepository.loadLibrary()
        let saved = try XCTUnwrap(reopened.items.first { $0.id == item.id })
        XCTAssertEqual(saved.attachmentPath, item.attachmentPath)
        XCTAssertEqual(saved.coverPath, item.coverPath)
        if let attachmentPath = saved.attachmentPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent(attachmentPath).path))
        }
    }

    func testImageImportUsesCopiedFileAsCoverAndImageBlock() async throws {
        let rootDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let imageURL = rootDirectory.appendingPathComponent("source.png")
        try writePNG(at: imageURL)

        let importer = AttachmentImporter(rootDirectory: rootDirectory)
        let item = try await importer.importFile(at: imageURL, tagIDs: [], folderID: "")

        XCTAssertEqual(item.kind, .image)
        XCTAssertEqual(item.attachmentPath, item.coverPath)
        XCTAssertEqual(item.body.first?.kind, .image)
        XCTAssertEqual(item.body.first?.caption, "source.png")
        if let attachmentPath = item.attachmentPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent(attachmentPath).path))
        }
    }

    private func metadataOnlySnapshot() -> LibrarySnapshot {
        LibrarySnapshot(
            items: [],
            tags: [ReaderTag(id: "t-test", name: "Test", colorHex: "#112233")],
            folders: [ReaderFolder(id: "fo-test", name: "Tests")],
            platforms: []
        )
    }

    private func writeSearchablePDF(at url: URL, text: String) throws {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard
            let consumer = CGDataConsumer(data: data),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            XCTFail("Could not create PDF context")
            return
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (text as NSString).draw(
            in: CGRect(x: 72, y: 640, width: 468, height: 80),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black
            ]
        )
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        try data.write(to: url, options: .atomic)
    }

    private func writePNG(at url: URL) throws {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            XCTFail("Could not create PNG fixture")
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderAttachmentImporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
