import SwiftUI

enum ReaderStyle {
    static let minimumWindowSize = CGSize(width: 980, height: 640)
    static let preferredWindowSize = CGSize(width: 1540, height: 920)

    static let sidebarWidth: CGFloat = 248
    static let listWidth: CGFloat = 372
    static let aiWidth: CGFloat = 372
    static let compactListWidth: CGFloat = 320
    static let compactAIWidth: CGFloat = 320
    static let minimumReaderWidth: CGFloat = 420
    static let inlineAIThreshold: CGFloat = 1410
    static let toolbarHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 13

    static let accent = Color(red: 0.29, green: 0.45, blue: 0.74)
    static let amber = Color(red: 0.83, green: 0.59, blue: 0.25)
    static let star = Color(red: 0.85, green: 0.60, blue: 0.24)

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.96, green: 0.93, blue: 0.89).opacity(0.92)
            : Color(red: 0.16, green: 0.15, blue: 0.12).opacity(0.90)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.91, green: 0.88, blue: 0.82).opacity(0.55)
            : Color(red: 0.21, green: 0.19, blue: 0.16).opacity(0.60)
    }

    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.88, green: 0.84, blue: 0.78).opacity(0.36)
            : Color(red: 0.25, green: 0.22, blue: 0.18).opacity(0.40)
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 1.0, green: 0.97, blue: 0.92).opacity(0.09)
            : Color(red: 0.24, green: 0.20, blue: 0.15).opacity(0.09)
    }

    static func warmPane(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.16, green: 0.145, blue: 0.125).opacity(0.78) : Color(red: 0.97, green: 0.95, blue: 0.92).opacity(0.82)
    }

    static func sidebarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.18, green: 0.16, blue: 0.14).opacity(0.92)
            : Color(red: 0.945, green: 0.922, blue: 0.878)
    }

    static func readerBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.13, green: 0.115, blue: 0.10).opacity(0.90) : Color(red: 0.985, green: 0.975, blue: 0.95).opacity(0.92)
    }

    static func controlFill(_ scheme: ColorScheme) -> Color {
        text(scheme).opacity(scheme == .dark ? 0.08 : 0.055)
    }

    static func hoverFill(_ scheme: ColorScheme) -> Color {
        text(scheme).opacity(scheme == .dark ? 0.08 : 0.06)
    }

    static func selectionFill(_ scheme: ColorScheme) -> Color {
        amber.opacity(scheme == .dark ? 0.18 : 0.20)
    }

    static func wallpaper(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.22, blue: 0.17),
                    Color(red: 0.17, green: 0.14, blue: 0.12),
                    Color(red: 0.11, green: 0.105, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.92, blue: 0.86),
                Color(red: 0.93, green: 0.88, blue: 0.80),
                Color(red: 0.88, green: 0.90, blue: 0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func contentLayout(for width: CGFloat, wantsAIPanel: Bool) -> ContentLayoutMetrics {
        let showsAI = wantsAIPanel && width >= inlineAIThreshold
        let nonReaderWidth = sidebarWidth + compactListWidth + (showsAI ? compactAIWidth : 0)
        let remainingForReader = width - nonReaderWidth
        let pressure = max(0, min(1, (remainingForReader - minimumReaderWidth) / 240))

        let list = compactListWidth + (listWidth - compactListWidth) * pressure
        let ai = showsAI ? compactAIWidth + (aiWidth - compactAIWidth) * pressure : 0
        let reader = showsAI ? minimumReaderWidth : max(minimumReaderWidth, width - sidebarWidth - list)

        return ContentLayoutMetrics(
            listWidth: min(listWidth, max(compactListWidth, list)),
            aiWidth: min(aiWidth, max(compactAIWidth, ai)),
            readerMinWidth: reader,
            showsAIPanel: showsAI
        )
    }
}

struct ContentLayoutMetrics {
    let listWidth: CGFloat
    let aiWidth: CGFloat
    let readerMinWidth: CGFloat
    let showsAIPanel: Bool
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 6 {
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        } else {
            red = 0.5
            green = 0.5
            blue = 0.5
        }

        self.init(red: red, green: green, blue: blue)
    }
}

struct Hairline: View {
    var vertical = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(ReaderStyle.separator(scheme))
            .frame(width: vertical ? 0.5 : nil, height: vertical ? nil : 0.5)
    }
}
