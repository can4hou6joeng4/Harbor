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
    static var defaultValue: [OnboardingTarget: CGRect] = [:]

    static func reduce(value: inout [OnboardingTarget: CGRect], nextValue: () -> [OnboardingTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { current, next in
            next.area >= current.area ? next : current
        })
    }
}

extension View {
    func onboardingTarget(_ target: OnboardingTarget) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OnboardingTargetPreferenceKey.self,
                    value: [target: proxy.frame(in: .named(OnboardingCoordinateSpace.name))]
                )
            }
        }
    }
}

enum OnboardingCoordinateSpace {
    static let name = "ReaderOnboardingCoordinateSpace"
}

struct OnboardingOverlay: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    let targets: [OnboardingTarget: CGRect]

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.frame(in: .local)
            let targetFrame = resolvedTargetFrame(in: screen)
            let highlightFrame = targetFrame ?? fallbackFrame(in: screen)
            let cutoutFrame = padded(highlightFrame, by: 8, in: screen)
            let cardPosition = cardPosition(for: highlightFrame, in: screen)

            ZStack(alignment: .topLeading) {
                SpotlightScrim(screen: screen, cutout: cutoutFrame, opacity: scheme == .dark ? 0.56 : 0.38)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .zIndex(0)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ReaderStyle.amber, lineWidth: 2)
                    .frame(width: cutoutFrame.width, height: cutoutFrame.height)
                    .position(x: cutoutFrame.midX, y: cutoutFrame.midY)
                    .shadow(color: ReaderStyle.amber.opacity(0.34), radius: 18)
                    .allowsHitTesting(false)
                    .zIndex(1)

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
                .zIndex(2)
            }
            .animation(.easeInOut(duration: 0.16), value: store.onboardingStep)
        }
        .zIndex(90)
    }

    private var currentIndex: Int {
        ReaderOnboardingStep.allCases.firstIndex(of: store.onboardingStep) ?? 0
    }

    private func resolvedTargetFrame(in screen: CGRect) -> CGRect? {
        guard let frame = targets[store.onboardingStep.onboardingTarget] else {
            return nil
        }

        let visibleFrame = frame.intersection(screen)
        guard !visibleFrame.isNull, visibleFrame.width > 8, visibleFrame.height > 8 else {
            return nil
        }
        return visibleFrame
    }

    private func fallbackFrame(in screen: CGRect) -> CGRect {
        CGRect(
            x: max(24, (screen.width - 360) / 2),
            y: max(72, (screen.height - 220) / 2),
            width: min(360, screen.width - 48),
            height: 160
        )
    }

    private func padded(_ frame: CGRect, by padding: CGFloat, in screen: CGRect) -> CGRect {
        let expanded = frame.insetBy(dx: -padding, dy: -padding)
        let clipped = expanded.intersection(screen)
        return clipped.isNull ? expanded : clipped
    }

    private func cardPosition(for target: CGRect, in screen: CGRect) -> CGPoint {
        let cardSize = CGSize(width: min(360, max(300, screen.width - 48)), height: 210)
        let spacing: CGFloat = 18
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2
        let protectedTarget = target.insetBy(dx: -12, dy: -12)
        let bounds = screen.insetBy(dx: 24, dy: 24)
        let candidates = [
            CGPoint(x: protectedTarget.maxX + spacing + halfWidth, y: protectedTarget.midY),
            CGPoint(x: protectedTarget.minX - spacing - halfWidth, y: protectedTarget.midY),
            CGPoint(x: protectedTarget.midX, y: protectedTarget.maxY + spacing + halfHeight),
            CGPoint(x: protectedTarget.midX, y: protectedTarget.minY - spacing - halfHeight),
            CGPoint(x: screen.midX, y: screen.midY)
        ]

        for point in candidates {
            let cardFrame = CGRect(
                x: point.x - halfWidth,
                y: point.y - halfHeight,
                width: cardSize.width,
                height: cardSize.height
            )
            if bounds.contains(cardFrame), !cardFrame.intersects(protectedTarget) {
                return point
            }
        }

        return CGPoint(
            x: min(max(screen.midX, bounds.minX + halfWidth), bounds.maxX - halfWidth),
            y: min(max(screen.midY, bounds.minY + halfHeight), bounds.maxY - halfHeight)
        )
    }
}

private struct SpotlightScrim: View {
    let screen: CGRect
    let cutout: CGRect
    let opacity: Double

    var body: some View {
        Path { path in
            path.addRect(screen)
            path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 12, height: 12))
        }
        .fill(Color.black.opacity(opacity), style: FillStyle(eoFill: true))
        .ignoresSafeArea()
    }
}

private extension CGRect {
    var area: CGFloat {
        guard width > 0, height > 0 else { return 0 }
        return width * height
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
                .keyboardShortcut(.cancelAction)
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
                .keyboardShortcut(.defaultAction)
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
