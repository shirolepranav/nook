import SwiftUI
import SwiftData
import CoreSpotlight
import WidgetKit
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
    @State private var openedBackup: URL?
    @State private var toast: ToastMessage?
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
        // A box label's code (F8), a backup from Files (S-04), or "Open in Nook" from the share
        // sheet or Files (D48): the receipt review, then a new item.
        .onOpenURL { url in
            if let link = DeepLink(url: url) {
                open(link)
            } else if url.pathExtension == BackupService.fileExtension {
                openedBackup = url
            } else {
                openedReceipt = .file(url)
            }
        }
        .restoreBackup($openedBackup, toast: $toast)
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
        // A notification's View (04 §7): the item in a sheet, over whatever tab is open.
        .sheet(item: Bindable(router).openedItem) { item in
            NavigationStack { ItemDetailScreen(item: item).itemNavigation() }
        }
        .sheet(item: Bindable(router).openedRoom) { room in
            NavigationStack {
                RoomScreen(room: room)
                    .itemNavigation()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "xmark") { router.openedRoom = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: Bindable(router).showsWarranties) {
            NavigationStack {
                WarrantiesScreen()
                    .itemNavigation()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "xmark") { router.showsWarranties = false }
                        }
                    }
            }
        }
        .onChange(of: router.newItem) { _, request in
            guard let request else { return }
            router.newItem = nil
            var draft = ItemDraft(currencyCode: HomeCurrency.code,
                                  location: request.place.flatMap { PlaceQuery.location($0, in: context) })
            draft.name = request.name
            openedItem = draft
        }
        .onChange(of: router.link) { _, link in
            guard let link else { return }
            router.link = nil
            open(link)
        }
        .sheet(item: Bindable(router).openedSpot) { spot in
            NavigationStack {
                SpotScreen(spot: spot)
                    .itemNavigation()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "xmark") { router.openedSpot = nil }
                        }
                    }
            }
        }
        .toast($toast)
        .task {
            // Spotlight and the widgets follow every save (04 §8, D61).
            await SystemSurfaces(container: context.container).keepCurrent()
        }
        .onChange(of: scenePhase) { _, phase in
            // Hide values, the accent and Pro change without a save; widgets catch up here.
            if phase == .background { WidgetCenter.shared.reloadAllTimelines() }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            // A Spotlight result Nook indexed by hand, should iOS hand one over that way.
            if let id = (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init) {
                open(.item(id))
            }
        }
        .task {
            // Find's index: built after the first frame, then kept current on every save (04 §6).
            let library = SearchLibrary(container: context.container)
            self.library = library
            await library.keepCurrent()
        }
    }

    /// `nook://` links (D19, 04 §8). Things open in sheets over the current tab, as a
    /// notification's item does; a deleted target gets a note instead.
    private func open(_ link: DeepLink) {
        router.openedItem = nil
        router.openedSpot = nil
        router.openedRoom = nil
        router.showsWarranties = false
        switch link {
        case .spot(let qrID):
            let spot = try? context.fetch(FetchDescriptor<Spot>(predicate: #Predicate { $0.qrID == qrID })).first
            if let spot { router.openedSpot = spot } else {
                toast = ToastMessage(symbol: "shippingbox", "That box isn’t in Nook anymore.")
            }
        case .item(let id):
            let item = try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })).first
            if let item { router.openedItem = item } else {
                toast = ToastMessage(symbol: "questionmark.circle", "That item isn’t in Nook anymore.")
            }
        case .room(let id):
            // A spot or container from Spotlight or Shortcuts comes this way too (PlaceEntity).
            let room = try? context.fetch(FetchDescriptor<Room>(predicate: #Predicate { $0.id == id })).first
            let spot = try? context.fetch(FetchDescriptor<Spot>(predicate: #Predicate { $0.id == id })).first
            if let room { router.openedRoom = room } else if let spot { router.openedSpot = spot } else {
                toast = ToastMessage(symbol: "questionmark.circle", "That room isn’t in Nook anymore.")
            }
        case .find(let query):
            router.findQuery = query
            tab = .find
        case .scan:
            scansRoom = true
        case .warranties:
            router.showsWarranties = true
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
            // ponytail: with sync on, a file can arrive well before its row; 30 days covers any
            // sane gap. Files orphaned while syncing stay in iCloud until a purge.
            blobs.sweepOrphans(photos: files.photos, receipts: files.receipts,
                               grace: SyncSettings.isActive ? 30 * 86_400 : 3600)
        }.value
    }
}
