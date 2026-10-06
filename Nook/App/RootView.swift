import SwiftUI
import SwiftData
import NookKit
import NookUI

/// First run shows onboarding (O-01, O-02); after that, the tabs.
struct RootView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        if hasOnboarded {
            TabShell()
        } else {
            OnboardingFlow { hasOnboarded = true }
        }
    }
}

/// The adaptive shell (01 §1.1): a Liquid Glass tab bar on compact width, a sidebar on
/// regular width (Pro Max landscape, iPad). Size classes only, via the system (D29).
private struct TabShell: View {
    // Survives relaunch, and resizing an iPad window between compact and regular (S1).
    @SceneStorage("tab") private var tab: AppTab = .home
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]
    @State private var editsSelectedRoom = false
    @State private var arranging = false
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var roomTabsHidden = true

    private var selectedRoom: Room? {
        guard case .room(let id) = tab else { return nil }
        return rooms.first { $0.id == id }
    }

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
            // Regular width: the rooms in the sidebar, the selected one beside it (01 H-01).
            // Hidden on compact: iOS 27 puts `.sidebarOnly` tabs in the tab bar too. Hiding or
            // removing the selected tab in the same update crashes UIKit, so narrowing selects
            // Home first and hides the rooms a turn later (D35).
            TabSection("Rooms") {
                ForEach(rooms) { room in
                    Tab(room.name, systemImage: room.symbol, value: AppTab.room(room.id)) {
                        NavigationStack { RoomScreen(room: room) }
                    }
                    .tabPlacement(.sidebarOnly)
                    .hidden(roomTabsHidden)
                }
            }
            .sectionActions {
                Button("Arrange Rooms", systemImage: "arrow.up.arrow.down") { arranging = true }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultTabBarPlacement(.sidebar)               // D32: sidebar when there's room
        .tabViewSearchActivation(.searchTabSelection)   // choosing Find (or ⌘F) focuses the field
        .focusedSceneValue(\.selectedTab, $tab)
        .focusedSceneValue(\.editsSelectedRoom, selectedRoom == nil ? nil : $editsSelectedRoom)
        .sheet(isPresented: $editsSelectedRoom) {
            if let selectedRoom { RoomEditor(room: selectedRoom) }
        }
        .sheet(isPresented: $arranging) { ArrangeSheet.rooms }
        .onChange(of: rooms.map(\.id)) { _, ids in
            // A deleted room can't stay selected.
            if case .room(let id) = tab, !ids.contains(id) { tab = .home }
        }
        .onChange(of: sizeClass, initial: true) { _, size in
            guard size == .compact else { roomTabsHidden = false; return }
            if case .room = tab { tab = .home }
            Task { roomTabsHidden = true }   // after the selection has moved off the room
        }
        // Saves, moves and deletes undo with ⌘Z, the shake gesture and the Undo toast (04 §9).
        .onAppear { context.undoManager = undoManager }
    }
}
