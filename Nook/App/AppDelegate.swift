import SwiftUI
import SwiftData
import UserNotifications
import NookKit

/// Owns the store, so a reminder's action (Mark Returned, Snooze) works even when iOS wakes
/// the app in the background with no window, and catches a notification tap from a cold
/// start (04 §7).
@Observable @MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private(set) var container: ModelContainer?
    private(set) var reminders: Reminders?
    /// S-03 (D58). Starts only when this launch's store syncs.
    let syncStatus = SyncStatus()
    @ObservationIgnored private var fileSync: FileSync?
    /// True for the moment the store reopens with sync turned on or off.
    private(set) var isSwitchingStore = false
    let router = AppRouter()
    /// L-02, S-05 and the Private-item lock (PRD §9).
    let lock: AppLock = {
        #if DEBUG
        // UI tests stand in for Face ID; without a flag every ask passes, so a Private item
        // opens as before.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingStore") {
            // S-05 starts off; an earlier test may have left it on in the App Group.
            UserDefaults.nook.removeObject(forKey: AppLock.enabledKey)
            UserDefaults.nook.removeObject(forKey: AppLock.timingKey)
        }
        if let fake = AppLock.forTesting(arguments) { return fake }
        if arguments.contains("-uiTestingStore") { return AppLock(method: { .faceID }, authenticate: { _ in true }) }
        #endif
        return AppLock()
    }()
    let entitlements: EntitlementStore = {
        #if DEBUG
        // UI tests skip StoreKit: Pro, or Free with `-uiTestingFree YES` (D56, D58).
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingStore") { return EntitlementStore(forcedPro: !arguments.contains("-uiTestingFree")) }
        #endif
        return EntitlementStore()
    }()

    override init() {
        super.init()
        syncStatus.setSync = { [weak self] in await self?.setSync($0) }
        syncStatus.syncNow = { [weak self] in await self?.syncNow() }
        openStore()
    }

    func openStore() {
        container = NookApp.openStore()
        IntentStore.container = container
        IntentStore.router = router
        reminders = container.map { Reminders(container: $0) }
        startSync()
    }

    /// S-03's switch (D58). SwiftData can't start or stop mirroring an open store, so the store
    /// closes and reopens; the views go with it and come back on S-03.
    func setSync(_ on: Bool) async {
        guard on != SyncSettings.isOn else { return }
        SyncSettings.isOn = on
        #if DEBUG
        // UI tests' in-memory store would be lost by reopening; the switch alone is checked.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingStore") { return }
        #endif
        isSwitchingStore = true
        await fileSync?.stop()
        fileSync = nil
        syncStatus.stop()
        reminders = nil
        container = nil   // released before the next one opens the same file (D59)
        IntentStore.container = nil
        try? await Task.sleep(for: .milliseconds(300))
        router.reopensSync = true
        openStore()
        isSwitchingStore = false
        if on { UIApplication.shared.registerForRemoteNotifications() }
    }

    /// Rows mirror through SwiftData; files through `FileSync`; copies merge after imports.
    private func startSync() {
        guard let container, NookApp.syncs else { return }
        syncStatus.onImport = { [weak container] in
            guard let container else { return }
            _ = try? DedupeService(context: container.mainContext).run()
        }
        syncStatus.start()
        _ = try? DedupeService(context: container.mainContext).run()
        let status = syncStatus
        let files = FileSync { [weak self] event in
            Task { @MainActor in
                status.handle(event)
                // Another Apple Account: stop rather than mix two people's homes.
                if case .switchedAccounts = event { await self?.setSync(false) }
            }
        }
        fileSync = files
        let referenced = (try? ItemService(context: container.mainContext).referencedFiles())
            .map { $0.photos.map { (BlobStore.Folder.photos, $0) } + $0.receipts.map { (.receipts, $0) } } ?? []
        Task { await files.start { referenced } }
    }

    /// S-03's Sync Now. Rows have no "now" in SwiftData; they go on every save.
    func syncNow() async {
        try? await fileSync?.syncNow()
        syncStatus.checkAccount()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Reminders.registerCategories()
        if NookApp.syncs { application.registerForRemoteNotifications() }   // CloudKit's pushes
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-initializeCloudKitSchema") {
            do { try NookStore.initializeCloudKitSchema(); print("CloudKit schema initialized") }
            catch { print("CloudKit schema failed: \(error)") }
        }
        #endif
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier
        guard let item = (info[ReminderKey.itemID] as? String).flatMap(UUID.init),
              let record = (info[ReminderKey.recordID] as? String).flatMap(UUID.init) else { return }
        await handle(action: action, category: category, item: item, record: record)
    }

    private func handle(action: String, category: String, item itemID: UUID, record: UUID) async {
        guard let container, let reminders else { return }
        let context = container.mainContext
        let items = ItemService(context: context)
        switch action {
        case Reminders.Action.snooze:
            if category == ReminderRequest.Kind.warranty.category {
                if let warranty = try? context.fetch(FetchDescriptor<Warranty>(predicate: #Predicate { $0.id == record })).first {
                    items.snooze(warranty)
                }
            } else if let loan = try? context.fetch(FetchDescriptor<Loan>(predicate: #Predicate { $0.id == record })).first {
                items.snooze(loan)
            }
        case Reminders.Action.returned:
            if let loan = try? context.fetch(FetchDescriptor<Loan>(predicate: #Predicate { $0.id == record })).first {
                items.markReturned(loan)
            }
        default:   // a tap on the notification, or View
            if let item = try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == itemID })).first,
               item.deletedAt == nil {
                router.open(item)
            }
            return
        }
        try? context.save()
        await reminders.reconcile()
    }
}
