import SwiftUI
import SwiftData
import NookUI

/// The adaptive shell (01 §1.1): a Liquid Glass tab bar on compact width, a sidebar on
/// regular width (Pro Max landscape, iPad). Size classes only, via the system (D29).
struct RootView: View {
    // Survives relaunch, and resizing an iPad window between compact and regular (S1).
    @SceneStorage("tab") private var tab: AppTab = .home
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeScreen()
            }
            Tab("Find", systemImage: "magnifyingglass", value: AppTab.find, role: .search) {
                FindScreen()
            }
            Tab("Reports", systemImage: "doc.text", value: AppTab.reports) {
                ReportsScreen()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsScreen()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultTabBarPlacement(.sidebar)               // D32: sidebar when there's room
        .tabViewSearchActivation(.searchTabSelection)   // choosing Find (or ⌘F) focuses the field
        .focusedSceneValue(\.selectedTab, $tab)
        // Saves, moves and deletes undo with ⌘Z, the shake gesture and the Undo toast (04 §9).
        .onAppear { context.undoManager = undoManager }
    }
}
