import ReaderCore
import SwiftUI

@main
struct ReaderMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ReaderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.themeMode == .dark ? .dark : .light)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Reader") {
                Button("添加内容") {
                    store.addModalOpen = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("命令面板") {
                    store.commandPaletteOpen = true
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("全部标为已读") {
                    store.markAllRead()
                }

                Button(store.themeMode == .dark ? "切换为浅色外观" : "切换为深色外观") {
                    store.themeMode = store.themeMode == .dark ? .light : .dark
                }
            }
        }
    }
}
