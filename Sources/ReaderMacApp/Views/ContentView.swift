import ReaderCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ReaderStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let layout = ReaderStyle.contentLayout(for: proxy.size.width, wantsAIPanel: store.aiPanelOpen)

                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: ReaderStyle.sidebarWidth)

                    Hairline(vertical: true)

                    ItemListView()
                        .frame(width: layout.listWidth)

                    Hairline(vertical: true)

                    ReaderDetailView()
                        .frame(minWidth: layout.readerMinWidth, maxWidth: .infinity)

                    if layout.showsAIPanel {
                        Hairline(vertical: true)

                        AIAssistantView()
                            .frame(width: layout.aiWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReaderStyle.warmPane(scheme))
            .ignoresSafeArea(.container, edges: .top)

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
        .sheet(isPresented: $store.aiSettingsSheetOpen) {
            AISettingsView()
                .environmentObject(store)
        }
        .frame(
            minWidth: ReaderStyle.minimumWindowSize.width,
            minHeight: ReaderStyle.minimumWindowSize.height
        )
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
