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
    let router = AppRouter()

    override init() {
        super.init()
        openStore()
    }

    func openStore() {
        container = NookApp.openStore()
        reminders = container.map { Reminders(container: $0) }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Reminders.registerCategories()
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
