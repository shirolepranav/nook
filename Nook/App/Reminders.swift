import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications
import NookKit

/// Warranty and loan reminders (F4, F7): keeps iOS's pending list matching the store
/// (D13, 04 §7) and asks for permission the first time a reminder is saved (D15).
@Observable @MainActor
final class Reminders {
    enum Action {
        static let view = "VIEW"
        static let snooze = "SNOOZE"
        static let returned = "RETURNED"
    }

    static let refreshTask = "pranav.nook.reminders"

    /// Denied shows "Reminders are off" with Open Settings on I-01, I-06 and S-07.
    private(set) var status: UNAuthorizationStatus = .notDetermined
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private var pending: Task<Void, Never>?

    init(container: ModelContainer) {
        self.container = container
    }

    var isDenied: Bool { status == .denied }

    /// Run from the shell's `.task`: reconciles now, then shortly after every save.
    func keepCurrent() async {
        await reconcile()
        for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await reconcile()
            }
        }
    }

    /// Makes the pending notifications match the store. Cheap when nothing changed.
    func reconcile() async {
        await refreshStatus()
        guard status == .authorized || status == .provisional else { return }
        let container = container
        let settings = Self.settings
        let desired = await Task.detached(priority: .utility) {
            let records = ReminderPlanner.snapshots(in: ModelContext(container))
            return ReminderPlanner.desiredReminders(warranties: records.warranties, loans: records.loans,
                                                    settings: settings, now: .now)
        }.value
        await ReminderScheduler(center: center).reconcile(desired, text: Self.text)
        await Self.scheduleRefresh()
    }

    /// D15: asked when the first warranty or loan reminder is saved, never before.
    func askIfNeeded() async {
        await refreshStatus()
        guard status == .notDetermined else { return }
        #if DEBUG
        if Self.testStatus != nil { return }
        #endif
        _ = try? await center.requestAuthorization(options: [.alert, .sound])   // no badges: quiet by default
        await reconcile()
    }

    private func refreshStatus() async {
        #if DEBUG
        if let status = Self.testStatus { self.status = status; return }
        #endif
        status = await center.notificationSettings().authorizationStatus
    }

    // MARK: Settings (S-07)

    static var settings: ReminderSettings {
        let defaults = UserDefaults.nook
        let minutes = defaults.object(forKey: PreferenceKey.reminderMinutes) as? Int ?? 9 * 60
        return ReminderSettings(warranties: defaults.object(forKey: PreferenceKey.warrantyReminders) as? Bool ?? true,
                                loans: defaults.object(forKey: PreferenceKey.loanReminders) as? Bool ?? true,
                                hour: minutes / 60, minute: minutes % 60)
    }

    // MARK: Copy (01 §12)

    /// Private items are never named: notifications show on the Lock Screen (PRD §9).
    nonisolated static func text(for request: ReminderRequest) -> ReminderText {
        switch request.kind {
        case .warranty:
            let days = request.daysLeft
            if request.isPrivate {
                return ReminderText(body: days == 0 ? String(localized: "A private item's warranty ends today.")
                                                    : String(localized: "A private item's warranty ends in \(days) days."))
            }
            let name = request.itemName
            return ReminderText(body: days == 0 ? String(localized: "Your \(name) warranty ends today.")
                                                : String(localized: "Your \(name) warranty ends in \(days) days."))
        case .loan:
            let person = request.person
            let since = (request.since ?? .now).formatted(.dateTime.month(.abbreviated).day())
            let dueToday = request.due.map { Calendar.current.isDate($0, inSameDayAs: request.fireDate) } ?? true
            if request.isPrivate {
                return ReminderText(body: dueToday ? String(localized: "Something you lent \(person) is due back today.")
                                                   : String(localized: "Something you lent \(person) is overdue."))
            }
            let name = request.itemName
            if dueToday {
                return ReminderText(body: String(localized: "\(person) has had your \(name) since \(since). It's due back today."))
            }
            let due = (request.due ?? .now).formatted(.dateTime.month(.abbreviated).day())
            return ReminderText(body: String(localized: "\(person) has had your \(name) since \(since). It was due back \(due)."))
        }
    }

    /// WARRANTY: View, Snooze 1 Week. LOAN: Mark Returned, Snooze 1 Week (04 §7).
    static func registerCategories() {
        let view = UNNotificationAction(identifier: Action.view, title: String(localized: "View"), options: [.foreground])
        let snooze = UNNotificationAction(identifier: Action.snooze, title: String(localized: "Snooze 1 Week"))
        let returned = UNNotificationAction(identifier: Action.returned, title: String(localized: "Mark Returned"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: ReminderRequest.Kind.warranty.category, actions: [view, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: ReminderRequest.Kind.loan.category, actions: [returned, snooze], intentIdentifiers: []),
        ])
    }

    /// Background refresh tops up the list (only the soonest 60 are pending) for people who
    /// don't open the app for weeks (D13).
    /// iOS 27 deprecates `submit(_:)` for the async `submitTaskRequest(_:)` (D51).
    static func scheduleRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = .now.addingTimeInterval(24 * 3600)
        try? await BGTaskScheduler.shared.submitTaskRequest(request)
    }

    #if DEBUG
    /// UI tests: `-uiTestingNotifications granted|denied` stands in for the system prompt.
    static let testStatus: UNAuthorizationStatus? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiTestingNotifications"), flag + 1 < arguments.count else { return nil }
        return arguments[flag + 1] == "denied" ? .denied : .authorized
    }()
    #endif
}

extension EnvironmentValues {
    @Entry var reminders: Reminders?
}
