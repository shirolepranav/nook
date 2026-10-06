import SwiftUI
import SwiftData
import NookKit
import NookUI

@main
struct NookApp: App {
    @AppStorage(PreferenceKey.accent, store: .nook) private var accent: AccentChoice = .terracotta
    @AppStorage(PreferenceKey.theme, store: .nook) private var theme: ThemeChoice = .system
    @State private var container = Self.openStore()

    init() {
        NookAppearance.configure()
        // S-06: each launch starts with values hidden or shown as the user chose; the eye on
        // Home changes it for this session.
        let defaults = UserDefaults.nook
        defaults.set(defaults.bool(forKey: PreferenceKey.hideValuesByDefault), forKey: PreferenceKey.hideValues)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView().modelContainer(container)
                } else {
                    StoreErrorView { container = Self.openStore() }
                }
            }
            .nookAccent(accent)
            .preferredColorScheme(theme.colorScheme)
            .defaultAppStorage(.nook)   // every @AppStorage, NookUI's too, uses the App Group
        }
        .commands { NookCommands() }
    }

    /// The App Group store. UI tests launch with `-uiTestingStore <empty|small>` for a fresh
    /// in-memory store instead.
    private static func openStore() -> ModelContainer? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-uiTestingStore"), flag + 1 < arguments.count {
            return MainActor.assumeIsolated {
                PreviewStore.seeded(PreviewStore.Size(rawValue: arguments[flag + 1]) ?? .empty)
            }
        }
        #endif
        // Failing to open leaves the file untouched; the user sees a calm error, not a crash.
        return try? NookStore.makeContainer()
    }
}
