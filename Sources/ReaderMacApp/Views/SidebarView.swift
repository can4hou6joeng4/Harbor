import ReaderCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme
    @State private var openPlatforms: Set<String> = ["p-rss"]
    @State private var openFolders: Set<String> = ["fo-tech"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TrafficLights()
                Spacer()
                IconButton(
                    icon: store.themeMode == .dark ? "sun" : "moon",
                    title: "切换亮/暗",
                    size: 26,
                    iconSize: 15
                ) {
                    store.themeMode = store.themeMode == .dark ? .light : .dark
                }
                IconButton(icon: "plus", title: "添加内容", size: 26, iconSize: 16) {
                    store.addModalOpen = true
                }
            }
            .frame(height: ReaderStyle.toolbarHeight)
            .padding(.horizontal, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 1) {
                        ForEach(store.smartViews) { smart in
                            SidebarRow(
                                title: smart.name,
                                icon: smart.icon,
                                count: store.count(forSmartView: smart.id, fallback: smart.fallbackCount),
                                isSelected: store.activeViewID == smart.id
                            ) {
                                store.selectView(smart.id)
                            }
                        }
                    }

                    SidebarSection(
                        title: "订阅源",
                        actionIcon: "plus",
                        actionTitle: "添加/管理订阅源",
                        headerOnboardingTarget: .rss
                    ) {
                        store.subscriptionsOpen = true
                    } content: {
                        ForEach(store.platforms) { platform in
                            let isOpen = openPlatforms.contains(platform.id)
                            SidebarRow(
                                title: platform.name,
                                icon: platform.icon,
                                count: platform.feeds.reduce(0) { $0 + $1.count },
                                isSelected: store.activeViewID == platform.id,
                                disclosureOpen: isOpen,
                                onDisclosure: { togglePlatform(platform.id) }
                            ) {
                                store.selectView(platform.id)
                            }

                            if isOpen {
                                ForEach(platform.feeds) { feed in
                                    SidebarRow(
                                        title: feed.name,
                                        count: feed.count,
                                        isSelected: store.activeViewID == feed.id,
                                        indent: 22,
                                        monogram: feed.monogram,
                                        monogramColor: Color(hex: feed.colorHex)
                                    ) {
                                        store.selectView(feed.id)
                                    }
                                }
                            }
                        }
                    }

                    SidebarSection(title: "目录", actionIcon: "plus") {
                        store.showToast("新建目录尚未连接到持久化")
                    } content: {
                        ForEach(store.folders) { folder in
                            let isOpen = openFolders.contains(folder.id)
                            SidebarRow(
                                title: folder.name,
                                icon: "folder",
                                count: folder.count,
                                isSelected: store.activeViewID == folder.id,
                                disclosureOpen: folder.children.isEmpty ? nil : isOpen,
                                onDisclosure: folder.children.isEmpty ? nil : { toggleFolder(folder.id) },
                                reserveDisclosureSpace: folder.children.isEmpty
                            ) {
                                store.selectView(folder.id)
                            }

                            if isOpen {
                                ForEach(folder.children) { child in
                                    SidebarRow(
                                        title: child.name,
                                        icon: "folder",
                                        count: child.count,
                                        isSelected: store.activeViewID == child.id,
                                        indent: 22
                                    ) {
                                        store.selectView(child.id)
                                    }
                                }
                            }
                        }
                    }

                    SidebarSection(title: "标签") {
                        ForEach(store.tags) { tag in
                            SidebarRow(
                                title: tag.name,
                                count: store.tagCount(tag.id),
                                isSelected: store.activeViewID == tag.id,
                                dotColor: Color(hex: tag.colorHex)
                            ) {
                                store.selectView(tag.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .padding(.bottom, 14)
            }

            Hairline()

            HStack(spacing: 8) {
                Icon(name: store.isSyncingFeeds ? "rss" : "check-circle", size: 15)
                    .foregroundStyle(store.isSyncingFeeds ? ReaderStyle.accent : Color(red: 0.18, green: 0.76, blue: 0.38))
                Text(store.isSyncingFeeds ? "正在同步订阅" : "数据保存在本地")
                    .font(.system(size: 12))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                Spacer()
                IconButton(icon: "gear", title: "设置", size: 26, iconSize: 15) {
                    store.openAISettings()
                }
                .onboardingTarget(.aiSettings)
                IconButton(icon: "help", title: "新手引导", size: 26, iconSize: 15) {
                    store.openOnboarding()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
        }
        .background(ReaderStyle.sidebarBackground(scheme))
        .onboardingTarget(.sidebar)
    }

    private func togglePlatform(_ id: String) {
        if openPlatforms.contains(id) {
            openPlatforms.remove(id)
        } else {
            openPlatforms.insert(id)
        }
    }

    private func toggleFolder(_ id: String) {
        if openFolders.contains(id) {
            openFolders.remove(id)
        } else {
            openFolders.insert(id)
        }
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    var actionIcon: String?
    var actionTitle: String?
    var headerOnboardingTarget: OnboardingTarget?
    var action: (() -> Void)?
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    init(
        title: String,
        actionIcon: String? = nil,
        actionTitle: String? = nil,
        headerOnboardingTarget: OnboardingTarget? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionIcon = actionIcon
        self.actionTitle = actionTitle
        self.headerOnboardingTarget = headerOnboardingTarget
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                Spacer()
                if let actionIcon, let action {
                    IconButton(icon: actionIcon, title: actionTitle ?? title, size: 26, iconSize: 13, action: action)
                        .opacity(hovering ? 1 : 0.76)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .onboardingTarget(headerOnboardingTarget)

            content
        }
        .onHover { hovering = $0 }
    }
}

private struct SidebarRow: View {
    let title: String
    var icon: String?
    var count: Int = 0
    var isSelected = false
    var disclosureOpen: Bool?
    var onDisclosure: (() -> Void)?
    var indent: CGFloat = 0
    var monogram: String?
    var monogramColor: Color?
    var dotColor: Color?
    var reserveDisclosureSpace = false
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let disclosureOpen {
                    Button(action: { onDisclosure?() }) {
                        Icon(name: "chev", size: 10)
                            .rotationEffect(.degrees(disclosureOpen ? 90 : 0))
                            .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                            .frame(width: 12, height: 18)
                    }
                    .buttonStyle(.plain)
                } else if reserveDisclosureSpace {
                    Color.clear.frame(width: 12, height: 18)
                }

                if let monogram {
                    Avatar(text: monogram, color: monogramColor ?? ReaderStyle.accent, size: 18)
                } else if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 9, height: 9)
                        .padding(.leading, 3)
                        .padding(.trailing, 1)
                } else if let icon {
                    Icon(name: icon, size: 16)
                        .foregroundStyle(isSelected ? ReaderStyle.amber : ReaderStyle.accent)
                }

                Text(title)
                    .font(.system(size: 13.5, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                if count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.system(size: 12))
                        .foregroundStyle(ReaderStyle.tertiaryText(scheme))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(ReaderStyle.text(scheme))
            .padding(.leading, 9 + indent)
            .padding(.trailing, 9)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? ReaderStyle.selectionFill(scheme) : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(ReaderStyle.amber)
                        .frame(width: 2.5, height: 18)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
