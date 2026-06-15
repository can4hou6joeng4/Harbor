import Foundation

public protocol CaptureAssetStore: Sendable {
    func store(data: Data, preferredExtension: String) async throws -> String
}

public enum CaptureAssetStoreError: LocalizedError, Sendable {
    case invalidExtension

    public var errorDescription: String? {
        switch self {
        case .invalidExtension:
            return "无法识别封面文件类型"
        }
    }
}

public final class LocalCaptureAssetStore: CaptureAssetStore, @unchecked Sendable {
    private let rootDirectory: URL

    public convenience init(fileManager: FileManager = .default) throws {
        try self.init(rootDirectory: Self.defaultRootDirectory(fileManager: fileManager))
    }

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public static func defaultRootDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ReaderMacApp", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public func store(data: Data, preferredExtension: String) async throws -> String {
        let fileExtension = try sanitizedExtension(preferredExtension)
        let relativePath = "Attachments/\(UUID().uuidString).\(fileExtension)"
        let fileURL = rootDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
        return relativePath
    }

    private func sanitizedExtension(_ preferredExtension: String) throws -> String {
        let cleaned = preferredExtension
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ". \n\t"))
            .filter { $0.isLetter || $0.isNumber }
        guard !cleaned.isEmpty else {
            throw CaptureAssetStoreError.invalidExtension
        }
        return String(cleaned.prefix(8))
    }
}
