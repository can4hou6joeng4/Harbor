import ReaderCore
import OSLog
import Sparkle
import SwiftUI

@main
struct ReaderMacApp: App {
    private static let logger = Logger(subsystem: "ReaderMacApp", category: "Persistence")

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: ReaderStore
    @State private var databaseFallbackWarning: DatabaseFallbackWarning?
    private let updaterController = ReaderUpdaterController()
    private let updateChecksEnabled = ReaderUpdateConfiguration.sparkleUpdatesEnabled

    init() {
        let repository: any ReaderRepository
        let warning: DatabaseFallbackWarning?
        do {
            repository = try GRDBRepository()
            warning = nil
        } catch {
            Self.logger.error("Failed to initialize GRDB repository: \(String(describing: error), privacy: .public)")
            repository = InMemoryRepository()
            warning = DatabaseFallbackWarning(
                message: "本地数据库不可用,本次会话数据不会保存"
            )
        }
        _store = StateObject(wrappedValue: ReaderStore(repository: repository, loadOnInit: true))
        _databaseFallbackWarning = State(initialValue: warning)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.themeMode == .dark ? .dark : .light)
                .background(WindowConfigurator())
                .alert(item: $databaseFallbackWarning) { warning in
                    Alert(
                        title: Text("本地数据库不可用"),
                        message: Text(warning.message),
                        dismissButton: .default(Text("知道了"))
                    )
                }
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

                if updateChecksEnabled {
                    Button("检查更新...") {
                        updaterController.checkForUpdates()
                    }
                }

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

private struct DatabaseFallbackWarning: Identifiable {
    let id = UUID()
    let message: String
}

private enum ReaderUpdateConfiguration {
    static let sparkleUpdatesEnabled = Bundle.main.object(
        forInfoDictionaryKey: "ReaderEnableSparkleUpdates"
    ) as? Bool ?? false
}

private final class ReaderUpdaterController {
    private let controller: SPUStandardUpdaterController?

    init() {
        guard ReaderUpdateConfiguration.sparkleUpdatesEnabled else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
