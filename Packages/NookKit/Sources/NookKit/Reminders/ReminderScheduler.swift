import Foundation
import UserNotifications

/// The words of one notification, written by the app (its string catalog has the copy).
public struct ReminderText: Equatable, Sendable {
    public var title: String
    public var body: String

    public init(title: String = "", body: String) {
        (self.title, self.body) = (title, body)
    }
}

/// The notification center, injected so tests use a fake (05 §1).
public protocol NotificationScheduling: Sendable {
    /// Nook's pending reminders: id → fingerprint.
    func pendingReminders() async -> [String: String]
    func add(_ request: ReminderRequest, text: ReminderText, fingerprint: String) async throws
    func removeReminders(_ ids: [String])
}

/// The rolling scheduler's other half (D13): makes the pending list match the plan, removing
/// and adding only what changed.
public struct ReminderScheduler: Sendable {
    let center: NotificationScheduling

    public init(center: NotificationScheduling) {
        self.center = center
    }

    public func reconcile(_ desired: [ReminderRequest], text: (ReminderRequest) -> ReminderText) async {
        let pending = await center.pendingReminders()
        let wanted = desired.map { request in
            let text = text(request)
            return (request, text, Self.fingerprint(request, text))
        }
        // Adding with an id that's pending replaces it, so only ids no longer wanted are removed.
        let ids = Set(desired.map(\.id))
        let stale = pending.keys.filter { !ids.contains($0) }
        if !stale.isEmpty { center.removeReminders(Array(stale)) }
        for (request, text, fingerprint) in wanted where pending[request.id] != fingerprint {
            try? await center.add(request, text: text, fingerprint: fingerprint)
        }
    }

    static func fingerprint(_ request: ReminderRequest, _ text: ReminderText) -> String {
        let c = request.components
        return [c.year, c.month, c.day, c.hour, c.minute].map { String($0 ?? -1) }.joined(separator: "-")
            + "|" + text.title + "|" + text.body
    }
}

/// userInfo keys on Nook's notifications.
public enum ReminderKey {
    public static let itemID = "itemID"
    public static let recordID = "recordID"
    public static let fingerprint = "fingerprint"
}

extension UNUserNotificationCenter: NotificationScheduling {
    public func pendingReminders() async -> [String: String] {
        let requests = await pendingNotificationRequests()
        return Dictionary(requests.compactMap { request -> (String, String)? in
            guard ReminderRequest.idPrefixes.contains(where: request.identifier.hasPrefix) else { return nil }
            return (request.identifier, request.content.userInfo[ReminderKey.fingerprint] as? String ?? "")
        }, uniquingKeysWith: { a, _ in a })
    }

    public func add(_ request: ReminderRequest, text: ReminderText, fingerprint: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.categoryIdentifier = request.kind.category
        content.threadIdentifier = request.kind.category
        content.userInfo = [ReminderKey.itemID: request.itemID.uuidString,
                            ReminderKey.recordID: request.recordID.uuidString,
                            ReminderKey.fingerprint: fingerprint]
        let trigger = UNCalendarNotificationTrigger(dateMatching: request.components, repeats: false)
        try await add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    public func removeReminders(_ ids: [String]) {
        removePendingNotificationRequests(withIdentifiers: ids)
    }
}
