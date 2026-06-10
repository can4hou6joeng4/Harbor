import SwiftUI

enum ReaderStyle {
    static let sidebarWidth: CGFloat = 248
    static let listWidth: CGFloat = 372
    static let aiWidth: CGFloat = 372
    static let toolbarHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 13

    static let accent = Color(red: 0.29, green: 0.45, blue: 0.74)
    static let amber = Color(red: 0.82, green: 0.58, blue: 0.25)
    static let star = Color(red: 0.85, green: 0.60, blue: 0.24)

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.95, green: 0.92, blue: 0.88) : Color(red: 0.18, green: 0.16, blue: 0.13)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        text(scheme).opacity(scheme == .dark ? 0.58 : 0.62)
    }

    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        text(scheme).opacity(scheme == .dark ? 0.36 : 0.42)
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        text(scheme).opacity(scheme == .dark ? 0.11 : 0.10)
    }

    static func warmPane(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.16, green: 0.145, blue: 0.125).opacity(0.78) : Color(red: 0.97, green: 0.95, blue: 0.92).opacity(0.82)
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
        amber.opacity(scheme == .dark ? 0.18 : 0.16)
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
