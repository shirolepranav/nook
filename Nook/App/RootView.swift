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
    @State private var addsItem = false
    @State private var scansRoom = false
    @State private var openedReceipt: ReceiptSource?
    @State private var openedItem: ItemDraft?
    @State private var library: SearchLibrary?
    @Environment(AppRouter.self) private var router
    @Environment(\.reminders) private var reminders
    @Environment(\.scenePhase) private var scenePhase

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
                        NavigationStack { RoomScreen(room: room).itemNavigation() }
                    }
                    .tabPlacement(.sidebarOnly)
                    .hidden(roomTabsHidden)
                }
            }
            .tabPlacement(.sidebarOnly)   // iPad portrait: the floating bar is the 4 tabs (iPadHome board)
            .sectionActions {
                Button("Arrange Rooms", systemImage: "arrow.up.arrow.down") { arranging = true }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(\.windowSizeClass, sizeClass)   // read inside sheets (MovePicker, D45)
        .environment(\.searchLibrary, library)
        .defaultTabBarPlacement(.sidebar)               // D32: sidebar when there's room
        .tabViewSearchActivation(.searchTabSelection)   // choosing Find (or ⌘F) focuses the field
        .focusedSceneValue(\.selectedTab, $tab)
        .focusedSceneValue(\.addItem, MenuAction { addsItem = true })
        .focusedSceneValue(\.scanRoom, MenuAction { scansRoom = true })
        .quickAdd(isPresented: $addsItem, at: selectedRoom.map { Location(room: $0) })
        .roomScan(isPresented: $scansRoom, at: selectedRoom.map { Location(room: $0) })
        // "Open in Nook" from the share sheet or Files (D48): the receipt review, then a new item.
        .onOpenURL { url in openedReceipt = .file(url) }
        .receiptScan($openedReceipt) { result in
            var draft = ItemDraft(currencyCode: HomeCurrency.code, location: selectedRoom.map { Location(room: $0) })
            result.apply(to: &draft)
            openedItem = draft
        }
        .newItemEditor($openedItem)
        #if DEBUG
        .task {
            // UI tests: open the fixture receipt as if another app had shared it.
            guard ProcessInfo.processInfo.arguments.contains("-uiTestingOpenReceipt"),
                  let data = CaptureFixtures.receipt?.jpegData(compressionQuality: 0.9) else { return }
            let url = FileManager.default.temporaryDirectory.appending(path: "Shared receipt.jpg")
            try? data.write(to: url)
            openedReceipt = .file(url)
        }
        #endif
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
        .task { await tidyUp() }
        // Reminders follow every save, and are checked again whenever the app comes back,
        // since notification permission can change in Settings (04 §7).
        .task { await reminders?.keepCurrent() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reminders?.reconcile() } }
        }
        .onChange(of: router.request?.id, initial: true) {
            if let request = router.request { tab = request.tab }   // its tab root pushes and clears it
        }
        .task {
            // Find's index: built after the first frame, then kept current on every save (04 §6).
            let library = SearchLibrary(container: context.container)
            self.library = library
            await library.keepCurrent()
        }
    }

    /// D14, D40: after the first frame, purge what's been in Recently Deleted 30 days, then
    /// sweep files no row points at.
    private func tidyUp() async {
        let items = ItemService(context: context)
        try? items.purgeExpired()
        try? context.save()
        guard let files = try? items.referencedFiles() else { return }
        let blobs = BlobStore.shared
        await Task.detached(priority: .background) {
            blobs.sweepOrphans(photos: files.photos, receipts: files.receipts)
        }.value
    }
}
