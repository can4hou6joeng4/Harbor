import Foundation

public actor InMemoryRepository: ReaderRepository {
    private var snapshot: LibrarySnapshot

    public init(snapshot: LibrarySnapshot = .sample) {
        self.snapshot = snapshot
    }

    public func loadLibrary() async throws -> LibrarySnapshot {
        snapshot
    }

    public func saveItem(_ item: ReaderItem) async throws {
        if let index = snapshot.items.firstIndex(where: { $0.id == item.id }) {
            snapshot.items[index] = item
        } else {
            snapshot.items.insert(item, at: 0)
        }
    }

    public func deleteItem(id: String) async throws {
        snapshot.items.removeAll { $0.id == id }
        snapshot.readingOffsets[id] = nil
    }

    public func setItemFlags(id: String, isUnread: Bool?, isFavorite: Bool?) async throws {
        guard let index = snapshot.items.firstIndex(where: { $0.id == id }) else { return }
        if let isUnread {
            snapshot.items[index].isUnread = isUnread
        }
        if let isFavorite {
            snapshot.items[index].isFavorite = isFavorite
        }
    }

    public func saveHighlights(itemID: String, _ highlights: [Highlight]) async throws {
        guard let index = snapshot.items.firstIndex(where: { $0.id == itemID }) else { return }
        snapshot.items[index].highlights = highlights
    }

    public func saveReadingState(itemID: String, progress: Double, offset: Double) async throws {
        guard let index = snapshot.items.firstIndex(where: { $0.id == itemID }) else { return }
        snapshot.items[index].progress = min(max(progress, 0), 1)
        snapshot.readingOffsets[itemID] = max(0, offset)
    }

    public func search(_ query: String) async throws -> [String] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        return snapshot.items.compactMap { item in
            let body = item.body.map { "\($0.text) \($0.translation) \($0.caption ?? "")" }.joined(separator: " ")
            let haystack = [item.title, item.excerpt, body].joined(separator: " ").lowercased()
            return haystack.contains(normalized) ? item.id : nil
        }
    }
}
