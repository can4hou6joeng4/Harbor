import Foundation

public struct LibrarySnapshot: Hashable, Sendable {
    public var items: [ReaderItem]
    public var tags: [ReaderTag]
    public var folders: [ReaderFolder]
    public var platforms: [PlatformSource]
    public var readingOffsets: [String: Double]

    public init(
        items: [ReaderItem],
        tags: [ReaderTag],
        folders: [ReaderFolder],
        platforms: [PlatformSource],
        readingOffsets: [String: Double] = [:]
    ) {
        self.items = items
        self.tags = tags
        self.folders = folders
        self.platforms = platforms
        self.readingOffsets = readingOffsets
    }

    public static var empty: LibrarySnapshot {
        LibrarySnapshot(items: [], tags: [], folders: [], platforms: [])
    }

    public static var sample: LibrarySnapshot {
        LibrarySnapshot(
            items: SampleLibrary.items,
            tags: SampleLibrary.tags,
            folders: SampleLibrary.folders,
            platforms: SampleLibrary.platforms
        )
    }
}

public protocol ReaderRepository: Sendable {
    func loadLibrary() async throws -> LibrarySnapshot
    func saveItem(_ item: ReaderItem) async throws
    func saveFeed(_ feed: Feed, platformID: String) async throws
    func updateFeedMetadata(id: String, lastFetchedAt: Date, etag: String?, lastModified: String?) async throws
    func containsItem(feedID: String, guid: String) async throws -> Bool
    func deleteItem(id: String) async throws
    func setItemFlags(id: String, isUnread: Bool?, isFavorite: Bool?) async throws
    func saveHighlights(itemID: String, _ highlights: [Highlight]) async throws
    func saveReadingState(itemID: String, progress: Double, offset: Double) async throws
    func search(_ query: String) async throws -> [String]
}
