import SwiftUI
import NookUI

@main
struct NookApp: App {
    @AppStorage(PreferenceKey.accent, store: .nook) private var accent: AccentChoice = .terracotta
    @AppStorage(PreferenceKey.theme, store: .nook) private var theme: ThemeChoice = .system

    init() {
        NookAppearance.configure()
        // S-06: each launch starts with values hidden or shown as the user chose; the eye on
        // Home changes it for this session.
        let defaults = UserDefaults.nook
        defaults.set(defaults.bool(forKey: PreferenceKey.hideValuesByDefault), forKey: PreferenceKey.hideValues)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .nookAccent(accent)
                .preferredColorScheme(theme.colorScheme)
                .defaultAppStorage(.nook)   // every @AppStorage, NookUI's too, uses the App Group
        }
        .commands { NookCommands() }
    }
}
