import SwiftUI
import NookUI

@main
struct NookApp: App {
    init() {
        NookAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .nookAccent(.terracotta)   // S-06 makes this the user's choice (P1 PR 8)
        }
        .commands { NookCommands() }
    }
}
