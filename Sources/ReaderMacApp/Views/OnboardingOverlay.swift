import ReaderCore
import SwiftUI

enum OnboardingTarget: Hashable {
    case sidebar
    case addContent
    case rss
    case reader
    case aiSettings
}

struct OnboardingTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [OnboardingTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [OnboardingTarget: Anchor<CGRect>], nextValue: () -> [OnboardingTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func onboardingTarget(_ target: OnboardingTarget) -> some View {
        anchorPreference(key: OnboardingTargetPreferenceKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }
}

struct OnboardingOverlay: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    let targets: [OnboardingTarget: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.frame(in: .local)
            let targetFrame = resolvedTargetFrame(in: proxy)
            let highlightFrame = targetFrame ?? fallbackFrame(in: screen)
            let cardPosition = cardPosition(for: highlightFrame, in: screen)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.black.opacity(scheme == .dark ? 0.48 : 0.32))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .path(in: padded(highlightFrame, by: 8))
                    .fill(.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ReaderStyle.amber, lineWidth: 2)
                            .frame(width: padded(highlightFrame, by: 8).width, height: padded(highlightFrame, by: 8).height)
                            .position(x: padded(highlightFrame, by: 8).midX, y: padded(highlightFrame, by: 8).midY)
                    }
                    .shadow(color: ReaderStyle.amber.opacity(0.34), radius: 18)
                    .allowsHitTesting(false)

                OnboardingCard(
                    step: store.onboardingStep,
                    isFirst: currentIndex == 0,
                    isLast: currentIndex == ReaderOnboardingStep.allCases.count - 1,
                    progressText: "\(currentIndex + 1)/\(ReaderOnboardingStep.allCases.count)",
                    targetAvailable: targetFrame != nil,
                    onBack: { store.retreatOnboarding() },
                    onNext: { store.advanceOnboarding() },
                    onSkip: { store.skipOnboarding() }
                )
                .frame(width: min(360, max(300, screen.width - 48)))
                .position(cardPosition)
            }
            .animation(.easeInOut(duration: 0.16), value: store.onboardingStep)
        }
        .zIndex(90)
    }

    private var currentIndex: Int {
        ReaderOnboardingStep.allCases.firstIndex(of: store.onboardingStep) ?? 0
    }

    private func resolvedTargetFrame(in proxy: GeometryProxy) -> CGRect? {
        guard let anchor = targets[store.onboardingStep.onboardingTarget] else {
            return nil
        }
        let frame = proxy[anchor]
        guard frame.width > 4, frame.height > 4 else {
            return nil
        }
        return frame
    }

    private func fallbackFrame(in screen: CGRect) -> CGRect {
        CGRect(
            x: max(24, (screen.width - 360) / 2),
            y: max(72, (screen.height - 220) / 2),
            width: min(360, screen.width - 48),
            height: 160
        )
    }

    private func padded(_ frame: CGRect, by padding: CGFloat) -> CGRect {
        frame.insetBy(dx: -padding, dy: -padding)
    }

    private func cardPosition(for target: CGRect, in screen: CGRect) -> CGPoint {
        let cardSize = CGSize(width: min(360, max(300, screen.width - 48)), height: 210)
        let spacing: CGFloat = 18
        let preferredY: CGFloat

        if target.maxY + spacing + cardSize.height < screen.maxY - 18 {
            preferredY = target.maxY + spacing + cardSize.height / 2
        } else if target.minY - spacing - cardSize.height > screen.minY + 18 {
            preferredY = target.minY - spacing - cardSize.height / 2
        } else {
            preferredY = screen.midY
        }

        let preferredX = target.midX
        let halfWidth = cardSize.width / 2
        let x = min(max(preferredX, screen.minX + halfWidth + 24), screen.maxX - halfWidth - 24)
        let y = min(max(preferredY, screen.minY + cardSize.height / 2 + 24), screen.maxY - cardSize.height / 2 - 24)
        return CGPoint(x: x, y: y)
    }
}

private struct OnboardingCard: View {
    let step: ReaderOnboardingStep
    let isFirst: Bool
    let isLast: Bool
    let progressText: String
    let targetAvailable: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Icon(name: step.icon, size: 17)
                    .foregroundStyle(ReaderStyle.amber)
                Text(step.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ReaderStyle.text(scheme))
                Spacer()
                Text(progressText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            }

            Text(step.message)
                .font(.system(size: 13.5))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !targetAvailable {
                Text("当前窗口下目标区域不可见,可调整窗口或继续查看下一步。")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            }

            HStack(spacing: 9) {
                Button("跳过") {
                    onSkip()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReaderStyle.secondaryText(scheme))

                Spacer()

                TextIconButton(title: "上一步", icon: "back") {
                    onBack()
                }
                .disabled(isFirst)

                TextIconButton(title: isLast ? "完成" : "下一步", icon: isLast ? "check" : "chev", role: .primary) {
                    onNext()
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.32), radius: 28, y: 14)
    }
}

private extension ReaderOnboardingStep {
    var onboardingTarget: OnboardingTarget {
        switch self {
        case .sidebar: .sidebar
        case .addContent: .addContent
        case .rss: .rss
        case .reader: .reader
        case .aiSettings: .aiSettings
        }
    }

    var title: String {
        switch self {
        case .sidebar: "浏览你的资料库"
        case .addContent: "添加内容"
        case .rss: "管理 RSS 订阅源"
        case .reader: "阅读与整理"
        case .aiSettings: "AI 与设置"
        }
    }

    var message: String {
        switch self {
        case .sidebar:
            "左侧可以在收件箱、未读、收藏和稍后读之间切换,也能按订阅源、目录和标签浏览资料。"
        case .addContent:
            "顶部加号用于添加 URL、附件或 Markdown。URL 会先抓取预览,再保存到本地资料库。"
        case .rss:
            "订阅源标题旁的加号现在始终可见,点击即可打开管理窗口,粘贴 RSS 链接并订阅。"
        case .reader:
            "中间阅读区会保存阅读进度,工具栏可切换双语、收藏、分享或删除当前条目。"
        case .aiSettings:
            "右侧是 AI 助手。可生成摘要、翻译、对话和二创；底部设置可配置模型与 API Key。"
        }
    }

    var icon: String {
        switch self {
        case .sidebar: "stack"
        case .addContent: "plus"
        case .rss: "rss"
        case .reader: "doc"
        case .aiSettings: "sparkles"
        }
    }
}
