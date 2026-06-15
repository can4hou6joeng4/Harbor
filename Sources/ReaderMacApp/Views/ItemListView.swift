import ReaderCore
import SwiftUI

struct ItemListView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(store.activeViewName)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(ReaderStyle.text(scheme))
                        .lineLimit(1)

                    Spacer()

                    IconButton(icon: "sort", title: "排序:\(store.sortMode.title)") {
                        store.cycleSortMode()
                    }
                }

                Text(store.activeSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))

                SearchField(text: $store.query, placeholder: "搜索标题、正文、标签…")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(height: 108)

            Hairline()

            ScrollView {
                LazyVStack(spacing: 2) {
                    if store.visibleItems.isEmpty {
                        EmptyState(icon: "search", title: "没有匹配的内容")
                            .frame(height: 260)
                    } else {
                        ForEach(store.visibleItems) { item in
                            ItemCard(item: item, isSelected: item.id == store.selectedItemID)
                        }
                    }
                }
                .padding(6)
            }
        }
        .background(.regularMaterial)
    }
}

private struct ItemCard: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    private static let thumbnailSize: CGFloat = 62
    private static let thumbnailSpacing: CGFloat = 12

    let item: ReaderItem
    let isSelected: Bool

    private var tags: [ReaderTag] {
        item.tagIDs.compactMap { id in store.tags.first { $0.id == id } }
    }

    private var isVideo: Bool {
        item.kind == .youtube || item.kind == .video
    }

    private var usesDocumentArtwork: Bool {
        item.kind == .pdf
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                if item.isUnread {
                    Circle()
                        .fill(ReaderStyle.accent)
                        .frame(width: 7, height: 7)
                }

                Icon(name: iconName(for: item.kind), size: 13)
                    .foregroundStyle(kindColor(item.kind))

                Text(item.source)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReaderStyle.secondaryText(scheme))
                    .lineLimit(1)

                Spacer(minLength: 4)

                IconButton(
                    icon: item.isFavorite ? "star-fill" : "star",
                    title: item.isFavorite ? "取消收藏" : "收藏",
                    size: 22,
                    iconSize: 13,
                    tint: item.isFavorite ? ReaderStyle.star : ReaderStyle.tertiaryText(scheme)
                ) {
                    store.toggleFavorite(item.id)
                }

                Text(item.relativePublishedTime())
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                    .monospacedDigit()
            }

            HStack(alignment: .top, spacing: Self.thumbnailSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14.5, weight: item.isUnread ? .semibold : .medium))
                        .foregroundStyle(item.isUnread ? ReaderStyle.text(scheme) : ReaderStyle.secondaryText(scheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.excerpt)
                        .font(.system(size: 12.5))
                        .lineSpacing(2)
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if item.hasCover {
                    artworkThumbnail
                }
            }

            HStack(spacing: 6) {
                ForEach(tags.prefix(2)) { tag in
                    Chip(title: tag.name, color: Color(hex: tag.colorHex))
                }

                Spacer()

                HStack(spacing: 4) {
                    Icon(name: isVideo ? "play" : "clock", size: 11)
                    Text(item.duration ?? "\(item.readingTime ?? 1) 分钟")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                .lineLimit(1)
            }
            .padding(.trailing, item.hasCover ? Self.thumbnailSize + Self.thumbnailSpacing : 0)

            if item.progress > 0 && item.progress < 1 {
                GeometryReader { proxy in
                    Capsule()
                        .fill(ReaderStyle.separator(scheme).opacity(1.4))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(ReaderStyle.amber)
                                .frame(width: max(4, proxy.size.width * item.progress))
                        }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected ? ReaderStyle.selectionFill(scheme) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ReaderStyle.amber)
                    .frame(width: 3)
                    .padding(.vertical, 9)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onTapGesture {
            store.selectItem(item.id)
        }
    }

    private var artworkThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(usesDocumentArtwork ? Color.white.opacity(scheme == .dark ? 0.08 : 0.72) : ReaderStyle.controlFill(scheme))

            CoverArtwork(
                coverPath: item.coverPath,
                hue: item.hue,
                cornerRadius: usesDocumentArtwork ? 7 : 9,
                contentMode: usesDocumentArtwork ? .fit : .fill
            )
            .padding(usesDocumentArtwork ? 4 : 0)

            if isVideo {
                Icon(name: "play", size: 22)
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }
            if let duration = item.duration {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .padding(4)
                    }
                }
            }
        }
        .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    ReaderStyle.separator(scheme).opacity(usesDocumentArtwork ? 2.4 : 1.35),
                    lineWidth: usesDocumentArtwork ? 1 : 0.5
                )
        }
        .shadow(
            color: Color.black.opacity(usesDocumentArtwork ? (scheme == .dark ? 0.24 : 0.08) : 0.04),
            radius: usesDocumentArtwork ? 5 : 2,
            y: usesDocumentArtwork ? 2 : 1
        )
    }

    private func kindColor(_ kind: ReaderKind) -> Color {
        switch kind {
        case .rss: Color(hex: "#E0533D")
        case .weibo: Color(hex: "#E6162D")
        case .youtube, .video: Color(hex: "#CF2B2B")
        case .pdf: Color(hex: "#D8443A")
        case .image: Color(hex: "#C98A2B")
        default: ReaderStyle.secondaryText(scheme)
        }
    }
}
