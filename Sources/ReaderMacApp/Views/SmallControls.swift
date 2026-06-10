import AppKit
import ReaderCore
import SwiftUI

struct IconButton: View {
    let icon: String
    var title: String = ""
    var size: CGFloat = 30
    var iconSize: CGFloat = 16
    var isOn = false
    var tint: Color?
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Icon(name: icon, size: iconSize)
                .foregroundStyle(tint ?? (isOn ? ReaderStyle.accent : ReaderStyle.secondaryText(scheme)))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? ReaderStyle.accent.opacity(0.16) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

struct TextIconButton: View {
    let title: String
    let icon: String
    var role: Role = .plain
    let action: () -> Void

    enum Role {
        case plain
        case primary
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Icon(name: icon, size: 14)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(role == .primary ? Color.white : ReaderStyle.text(scheme))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(role == .primary ? ReaderStyle.accent : ReaderStyle.controlFill(scheme))
            )
            .overlay {
                if role == .plain {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let title: String
    var color: Color?
    var selected = false
    var icon: String?
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 5) {
                if let icon {
                    Icon(name: icon, size: 11)
                } else if let color {
                    Circle()
                        .fill(selected ? Color.white : color)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(selected ? Color.white : ReaderStyle.secondaryText(scheme))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(selected ? (color ?? ReaderStyle.accent) : ReaderStyle.controlFill(scheme))
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 7) {
            Icon(name: "search", size: 13)
                .foregroundStyle(ReaderStyle.tertiaryText(scheme))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !text.isEmpty {
                IconButton(icon: "close", title: "清空", size: 20, iconSize: 11) {
                    text = ""
                }
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(ReaderStyle.controlFill(scheme))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
        }
    }
}

struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            trafficButton(color: Color(red: 1.0, green: 0.37, blue: 0.34)) {
                NSApp.keyWindow?.performClose(nil)
            }
            trafficButton(color: Color(red: 1.0, green: 0.74, blue: 0.18)) {
                NSApp.keyWindow?.miniaturize(nil)
            }
            trafficButton(color: Color(red: 0.16, green: 0.78, blue: 0.25)) {
                NSApp.keyWindow?.zoom(nil)
            }
        }
        .frame(width: 52, height: 22)
    }

    private func trafficButton(color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

struct Avatar: View {
    let text: String
    var color: Color = ReaderStyle.accent
    var size: CGFloat = 22
    var round = true

    var body: some View {
        Text(String(text.prefix(1)))
            .font(.system(size: size <= 20 ? 10 : 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: round ? size / 2 : 6, style: .continuous)
                    .fill(color)
            )
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 14) {
            Icon(name: icon, size: 42)
                .foregroundStyle(ReaderStyle.tertiaryText(scheme))
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(ReaderStyle.tertiaryText(scheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
