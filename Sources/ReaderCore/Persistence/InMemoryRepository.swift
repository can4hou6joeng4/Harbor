import Foundation

public actor InMemoryRepository: ReaderRepository {
    private var snapshot: LibrarySnapshot

    public init(snapshot: LibrarySnapshot = .sample) {
        self.snapshot = snapshot
    }

    public func loadLibrary() async throws -> LibrarySnapshot {
        snapshotWithFeedCounts()
    }

    public func saveItem(_ item: ReaderItem) async throws {
        if let index = snapshot.items.firstIndex(where: { $0.id == item.id }) {
            snapshot.items[index] = item
        } else {
            snapshot.items.insert(item, at: 0)
        }
    }

    public func saveFeed(_ feed: Feed, platformID: String) async throws {
        let updatedFeed = feedWithCurrentCount(feed)
        if let platformIndex = snapshot.platforms.firstIndex(where: { $0.id == platformID }) {
            var feeds = snapshot.platforms[platformIndex].feeds
            if let feedIndex = feeds.firstIndex(where: { $0.id == feed.id }) {
                feeds[feedIndex] = updatedFeed
            } else {
                feeds.append(updatedFeed)
            }
            let platform = snapshot.platforms[platformIndex]
            snapshot.platforms[platformIndex] = PlatformSource(
                id: platform.id,
                name: platform.name,
                icon: platform.icon,
                feeds: feeds
            )
        } else {
            let info = Self.platformInfo(for: platformID)
            snapshot.platforms.append(
                PlatformSource(id: platformID, name: info.name, icon: info.icon, feeds: [updatedFeed])
            )
        }
    }

    public func updateFeedMetadata(id: String, lastFetchedAt: Date, etag: String?, lastModified: String?) async throws {
        updateFeed(id: id) { feed in
            Feed(
                id: feed.id,
                name: feed.name,
                monogram: feed.monogram,
                colorHex: feed.colorHex,
                count: feed.count,
                url: feed.url,
                lastFetchedAt: lastFetchedAt,
                etag: etag,
                lastModified: lastModified
            )
        }
    }

    public func containsItem(feedID: String, guid: String) async throws -> Bool {
        snapshot.items.contains { $0.feedID == feedID && $0.guid == guid }
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

    private func snapshotWithFeedCounts() -> LibrarySnapshot {
        LibrarySnapshot(
            items: snapshot.items,
            tags: snapshot.tags,
            folders: snapshot.folders,
            platforms: snapshot.platforms.map { platform in
                PlatformSource(
                    id: platform.id,
                    name: platform.name,
                    icon: platform.icon,
                    feeds: platform.feeds.map(feedWithCurrentCount)
                )
            },
            readingOffsets: snapshot.readingOffsets
        )
    }

    private func feedWithCurrentCount(_ feed: Feed) -> Feed {
        Feed(
            id: feed.id,
            name: feed.name,
            monogram: feed.monogram,
            colorHex: feed.colorHex,
            count: snapshot.items.filter { $0.feedID == feed.id }.count,
            url: feed.url,
            lastFetchedAt: feed.lastFetchedAt,
            etag: feed.etag,
            lastModified: feed.lastModified
        )
    }

    private func updateFeed(id: String, transform: (Feed) -> Feed) {
        for platformIndex in snapshot.platforms.indices {
            guard let feedIndex = snapshot.platforms[platformIndex].feeds.firstIndex(where: { $0.id == id }) else {
                continue
            }
            var feeds = snapshot.platforms[platformIndex].feeds
            feeds[feedIndex] = transform(feeds[feedIndex])
            let platform = snapshot.platforms[platformIndex]
            snapshot.platforms[platformIndex] = PlatformSource(
                id: platform.id,
                name: platform.name,
                icon: platform.icon,
                feeds: feeds
            )
            return
        }
    }

    private static func platformInfo(for id: String) -> (name: String, icon: String) {
        switch id {
        case "p-rss":
            return ("RSS", "rss")
        case "p-x":
            return ("X", "x")
        case "p-weibo":
            return ("微博", "weibo")
        case "p-yt":
            return ("YouTube", "youtube")
        default:
            return (id, "rss")
        }
    }
}
