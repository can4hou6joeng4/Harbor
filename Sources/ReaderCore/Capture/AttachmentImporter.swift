import AppKit
import AVFoundation
import Foundation
import NaturalLanguage
import PDFKit

public enum AttachmentImportError: LocalizedError, Sendable {
    case unsupportedFileType
    case unreadablePDF
    case copyFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "不支持的附件类型"
        case .unreadablePDF:
            return "无法读取 PDF"
        case .copyFailed:
            return "附件复制失败"
        }
    }
}

public final class AttachmentImporter: @unchecked Sendable {
    private let rootDirectory: URL
    private let now: @Sendable () -> Date

    public convenience init(fileManager: FileManager = .default, now: @escaping @Sendable () -> Date = { Date() }) throws {
        try self.init(rootDirectory: LocalCaptureAssetStore.defaultRootDirectory(fileManager: fileManager), now: now)
    }

    public init(rootDirectory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.rootDirectory = rootDirectory
        self.now = now
    }

    public func importFile(at sourceURL: URL, tagIDs: [String], folderID: String) async throws -> ReaderItem {
        let fileExtension = sourceURL.pathExtension.lowercased()
        switch fileExtension {
        case "pdf":
            return try importPDF(at: sourceURL, tagIDs: tagIDs, folderID: folderID)
        case "png", "jpg", "jpeg", "heic":
            return try importImage(at: sourceURL, tagIDs: tagIDs, folderID: folderID)
        case "mp4", "mov":
            return try await importVideo(at: sourceURL, tagIDs: tagIDs, folderID: folderID)
        default:
            throw AttachmentImportError.unsupportedFileType
        }
    }

    private func importPDF(at sourceURL: URL, tagIDs: [String], folderID: String) throws -> ReaderItem {
        let attachmentPath = try copyIntoAttachments(sourceURL)
        let copiedURL = rootDirectory.appendingPathComponent(attachmentPath)
        guard let document = PDFDocument(url: copiedURL) else {
            throw AttachmentImportError.unreadablePDF
        }

        var blocks: [ContentBlock] = []
        for index in 0..<document.pageCount {
            guard let text = document.page(at: index)?.string?.normalizedAttachmentText, !text.isEmpty else {
                continue
            }
            blocks.append(ContentBlock(kind: .paragraph, language: "", text: text))
        }

        let text = blocks.map(\.text).joined(separator: "\n")
        let language = Self.detectLanguage(in: text)
        for index in blocks.indices {
            blocks[index].language = language
        }

        let coverPath = try renderPDFCover(from: document)
        return ReaderItem(
            id: UUID().uuidString,
            type: "pdf",
            kind: .pdf,
            source: "附件 · PDF",
            author: "本地文件",
            title: sourceURL.lastPathComponent,
            excerpt: text.isEmpty ? "PDF 暂无可提取文本" : String(text.prefix(100)),
            publishedAt: now(),
            readingTime: max(1, Int(ceil(Double(text.count) / 400.0))),
            language: language,
            tagIDs: tagIDs,
            folderID: folderID,
            isFavorite: false,
            isUnread: true,
            progress: 0,
            hue: Self.hue(for: sourceURL.lastPathComponent),
            hasCover: coverPath != nil,
            attachmentPath: attachmentPath,
            coverPath: coverPath,
            body: blocks.isEmpty ? [ContentBlock(kind: .paragraph, language: language, text: "PDF 暂无可提取文本")] : blocks,
            summary: ReaderSummary(text: [], keys: [], tagSuggestions: [])
        )
    }

    private func importImage(at sourceURL: URL, tagIDs: [String], folderID: String) throws -> ReaderItem {
        let attachmentPath = try copyIntoAttachments(sourceURL)
        return ReaderItem(
            id: UUID().uuidString,
            type: "image",
            kind: .image,
            source: "附件 · 图片",
            author: "本地文件",
            title: sourceURL.lastPathComponent,
            excerpt: "已导入本地图片",
            publishedAt: now(),
            readingTime: 1,
            language: "zh",
            tagIDs: tagIDs,
            folderID: folderID,
            isFavorite: false,
            isUnread: true,
            progress: 0,
            hue: Self.hue(for: sourceURL.lastPathComponent),
            hasCover: true,
            attachmentPath: attachmentPath,
            coverPath: attachmentPath,
            body: [
                ContentBlock(kind: .image, language: "zh", text: attachmentPath, caption: sourceURL.lastPathComponent)
            ],
            summary: ReaderSummary(text: [], keys: [], tagSuggestions: [])
        )
    }

    private func importVideo(at sourceURL: URL, tagIDs: [String], folderID: String) async throws -> ReaderItem {
        let attachmentPath = try copyIntoAttachments(sourceURL)
        let copiedURL = rootDirectory.appendingPathComponent(attachmentPath)
        let asset = AVURLAsset(url: copiedURL)
        let durationTime = try? await asset.load(.duration)
        let duration = durationTime.map { Self.durationString(seconds: CMTimeGetSeconds($0)) } ?? nil

        return ReaderItem(
            id: UUID().uuidString,
            type: "video",
            kind: .video,
            source: "附件 · 视频",
            author: "本地文件",
            title: sourceURL.lastPathComponent,
            excerpt: "已导入本地视频",
            publishedAt: now(),
            duration: duration,
            language: "zh",
            tagIDs: tagIDs,
            folderID: folderID,
            isFavorite: false,
            isUnread: true,
            progress: 0,
            hue: Self.hue(for: sourceURL.lastPathComponent),
            hasCover: false,
            attachmentPath: attachmentPath,
            body: [
                ContentBlock(kind: .paragraph, language: "zh", text: "视频文件已保存到本地。")
            ],
            summary: ReaderSummary(text: [], keys: [], tagSuggestions: [])
        )
    }

    private func copyIntoAttachments(_ sourceURL: URL) throws -> String {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard !fileExtension.isEmpty else {
            throw AttachmentImportError.unsupportedFileType
        }
        let relativePath = "Attachments/\(UUID().uuidString).\(fileExtension)"
        let destinationURL = rootDirectory.appendingPathComponent(relativePath)
        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return relativePath
        } catch {
            throw AttachmentImportError.copyFailed
        }
    }

    private func renderPDFCover(from document: PDFDocument) throws -> String? {
        guard let page = document.page(at: 0) else { return nil }
        let image = page.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }

        let relativePath = "Attachments/\(UUID().uuidString).png"
        let destinationURL = rootDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: destinationURL, options: [.atomic])
        return relativePath
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

    private static func durationString(seconds: Double) -> String? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private extension String {
    var normalizedAttachmentText: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
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
