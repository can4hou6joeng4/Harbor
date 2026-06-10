import ReaderCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            ReaderStyle.wallpaper(scheme)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: ReaderStyle.sidebarWidth)

                Hairline(vertical: true)

                ItemListView()
                    .frame(width: ReaderStyle.listWidth)

                Hairline(vertical: true)

                ReaderDetailView()
                    .frame(minWidth: 430)

                if store.aiPanelOpen {
                    Hairline(vertical: true)

                    AIAssistantView()
                        .frame(width: ReaderStyle.aiWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .background(ReaderStyle.warmPane(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ReaderStyle.separator(scheme), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.25), radius: 46, y: 24)
            .padding(22)

            if store.commandPaletteOpen {
                CommandPaletteView()
            }

            if store.addModalOpen {
                AddContentModal()
            }

            if store.subscriptionsOpen {
                SubscriptionsModal()
            }

            if let toast = store.toastMessage {
                ToastView(message: toast)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: store.aiPanelOpen)
        .animation(.easeOut(duration: 0.16), value: store.toastMessage)
        .frame(minWidth: 1120, minHeight: 720)
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 9) {
                Icon(name: "check-circle", size: 15)
                    .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.35))
                Text(message)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(.bottom, 26)
        }
        .allowsHitTesting(false)
    }
}
