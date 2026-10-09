import Foundation
import SwiftData

/// What a warranty or loan reminder needs, read off the store so planning is pure (04 §7).
public struct WarrantySnapshot: Equatable, Sendable {
    public var id: UUID
    public var itemID: UUID
    public var itemName: String
    public var isPrivate: Bool
    public var endDate: Date
    public var offsetsDays: [Int]
    public var snoozedUntil: Date?

    public init(id: UUID = UUID(), itemID: UUID = UUID(), itemName: String, isPrivate: Bool = false,
                endDate: Date, offsetsDays: [Int] = Warranties.defaultOffsets, snoozedUntil: Date? = nil) {
        (self.id, self.itemID, self.itemName, self.isPrivate) = (id, itemID, itemName, isPrivate)
        (self.endDate, self.offsetsDays, self.snoozedUntil) = (endDate, offsetsDays, snoozedUntil)
    }
}

public struct LoanSnapshot: Equatable, Sendable {
    public var id: UUID
    public var itemID: UUID
    public var itemName: String
    public var isPrivate: Bool
    public var person: String
    public var lentAt: Date
    public var dueAt: Date
    public var snoozedUntil: Date?

    public init(id: UUID = UUID(), itemID: UUID = UUID(), itemName: String, isPrivate: Bool = false,
                person: String, lentAt: Date, dueAt: Date, snoozedUntil: Date? = nil) {
        (self.id, self.itemID, self.itemName, self.isPrivate) = (id, itemID, itemName, isPrivate)
        (self.person, self.lentAt, self.dueAt, self.snoozedUntil) = (person, lentAt, dueAt, snoozedUntil)
    }
}

/// S-07: which reminders are on and the time of day they come.
public struct ReminderSettings: Equatable, Sendable {
    public var warranties = true
    public var loans = true
    public var hour = 9
    public var minute = 0

    public init(warranties: Bool = true, loans: Bool = true, hour: Int = 9, minute: Int = 0) {
        (self.warranties, self.loans, self.hour, self.minute) = (warranties, loans, hour, minute)
    }
}

/// One pending notification. Its text is written by the app from these fields, so the copy
/// lives in the app's string catalog.
public struct ReminderRequest: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case warranty = "WARRANTY", loan = "LOAN"
        /// The notification category, which carries the actions (04 §7).
        public var category: String { rawValue }
    }

    /// Stable, so reconciling only touches what changed: `w.<warranty>.<offset>`,
    /// `w.<warranty>.snooze`, `l.<loan>`.
    public var id: String
    public var kind: Kind
    public var recordID: UUID
    public var itemID: UUID
    public var itemName: String
    public var isPrivate: Bool
    /// A floating local date and time, with no time zone: it fires at 9:00 wherever the
    /// phone is, and needs no rescheduling for daylight saving or travel (D50).
    public var components: DateComponents
    /// The same moment in today's time zone, for ordering and skipping past ones.
    public var fireDate: Date
    /// Warranty: whole days from the reminder to the end.
    public var daysLeft = 0
    /// Loan: who has it, since when, and when it's due.
    public var person = ""
    public var since: Date?
    public var due: Date?

    public static let idPrefixes = ["w.", "l."]
}

/// The rolling scheduler's pure half (D13, 04 §7): what should be pending, soonest first,
/// capped below iOS's 64, which leaves headroom.
public enum ReminderPlanner {
    public static let cap = 60

    public static func desiredReminders(warranties: [WarrantySnapshot], loans: [LoanSnapshot],
                                        settings: ReminderSettings, now: Date, calendar: Calendar = .current,
                                        cap: Int = cap) -> [ReminderRequest] {
        var requests: [ReminderRequest] = []

        func at(_ day: Date) -> (DateComponents, Date)? {
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            (parts.hour, parts.minute) = (settings.hour, settings.minute)
            return calendar.date(from: parts).map { (parts, $0) }
        }
        func exactly(_ moment: Date) -> (DateComponents, Date) {
            (calendar.dateComponents([.year, .month, .day, .hour, .minute], from: moment), moment)
        }

        if settings.warranties {
            for warranty in warranties where !warranty.offsetsDays.isEmpty {
                let endDay = calendar.startOfDay(for: warranty.endDate)
                func add(_ id: String, _ when: (DateComponents, Date)) {
                    let days = Warranties.daysLeft(until: endDay, now: when.1, calendar: calendar)
                    guard when.1 > now, days >= 0 else { return }
                    requests.append(ReminderRequest(id: id, kind: .warranty, recordID: warranty.id, itemID: warranty.itemID,
                                                    itemName: warranty.itemName, isPrivate: warranty.isPrivate,
                                                    components: when.0, fireDate: when.1, daysLeft: days))
                }
                for offset in Set(warranty.offsetsDays) {
                    guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay), let when = at(day) else { continue }
                    if let snoozed = warranty.snoozedUntil, when.1 < snoozed { continue }   // snoozed past it
                    add("w.\(warranty.id).\(offset)", when)
                }
                if let snoozed = warranty.snoozedUntil { add("w.\(warranty.id).snooze", exactly(snoozed)) }
            }
        }

        if settings.loans {
            for loan in loans {
                guard var when = at(loan.dueAt) else { continue }
                if let snoozed = loan.snoozedUntil, snoozed > when.1 { when = exactly(snoozed) }
                guard when.1 > now else { continue }
                requests.append(ReminderRequest(id: "l.\(loan.id)", kind: .loan, recordID: loan.id, itemID: loan.itemID,
                                                itemName: loan.itemName, isPrivate: loan.isPrivate,
                                                components: when.0, fireDate: when.1,
                                                person: loan.person, since: loan.lentAt, due: loan.dueAt))
            }
        }

        return Array(requests.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }.prefix(cap))
    }

    /// Reads warranties and loans that can remind: live items only, loans still out with a
    /// due date and Remind on. Not tied to an actor, like `SearchSnapshot`.
    public static func snapshots(in context: ModelContext) -> (warranties: [WarrantySnapshot], loans: [LoanSnapshot]) {
        let warranties = ((try? context.fetch(FetchDescriptor<Warranty>())) ?? []).compactMap { warranty -> WarrantySnapshot? in
            guard let item = warranty.item, item.deletedAt == nil, let end = warranty.endDate,
                  !warranty.reminderOffsetsDays.isEmpty else { return nil }
            return WarrantySnapshot(id: warranty.id, itemID: item.id, itemName: item.name, isPrivate: item.isPrivate,
                                    endDate: end, offsetsDays: warranty.reminderOffsetsDays,
                                    snoozedUntil: warranty.snoozedUntil)
        }
        let out = (try? context.fetch(FetchDescriptor<Loan>(predicate: #Predicate { $0.returnedAt == nil && $0.remind }))) ?? []
        let loans = out.compactMap { loan -> LoanSnapshot? in
            guard let item = loan.item, item.deletedAt == nil, let due = loan.dueAt else { return nil }
            return LoanSnapshot(id: loan.id, itemID: item.id, itemName: item.name, isPrivate: item.isPrivate,
                                person: loan.personName, lentAt: loan.lentAt, dueAt: due, snoozedUntil: loan.snoozedUntil)
        }
        return (warranties, loans)
    }
}
