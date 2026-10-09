import Foundation
import SwiftData
import Testing
@testable import NookKit

private func calendar(_ zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

private let ny = calendar("America/New_York")

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, in cal: Calendar = ny) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func plan(_ warranties: [WarrantySnapshot] = [], _ loans: [LoanSnapshot] = [],
                  settings: ReminderSettings = .init(), now: Date, cap: Int = ReminderPlanner.cap) -> [ReminderRequest] {
    ReminderPlanner.desiredReminders(warranties: warranties, loans: loans, settings: settings, now: now, calendar: ny, cap: cap)
}

@Test func warrantyRemindsThirtyAndSevenDaysBeforeAtNine() {
    let w = WarrantySnapshot(itemName: "Dishwasher", endDate: at(2026, 12, 15, 14))
    let reminders = plan([w], now: at(2026, 10, 9))
    #expect(reminders.map(\.id) == ["w.\(w.id).30", "w.\(w.id).7"])
    #expect(reminders.map(\.daysLeft) == [30, 7])
    #expect(reminders[0].components == DateComponents(year: 2026, month: 11, day: 15, hour: 9, minute: 0))
    #expect(reminders[0].components.timeZone == nil)   // floating: 9:00 wherever the phone is (D50)
    #expect(reminders[1].fireDate == at(2026, 12, 8, 9))
}

@Test func daylightSavingKeepsNineInTheMorning() {
    // US clocks spring forward on Mar 8, 2026; the 7-day reminder falls after it.
    let w = WarrantySnapshot(itemName: "Lamp", endDate: at(2026, 3, 12))
    let reminders = plan([w], now: at(2026, 1, 1))
    #expect(reminders.map(\.fireDate) == [at(2026, 2, 10, 9), at(2026, 3, 5, 9)])
    #expect(ny.component(.hour, from: reminders[1].fireDate) == 9)
}

@Test func leapDayAndTimeOfDay() {
    let w = WarrantySnapshot(itemName: "TV", endDate: at(2028, 3, 7), offsetsDays: [7])
    let reminders = plan([w], settings: .init(hour: 18, minute: 30), now: at(2028, 1, 1))
    #expect(reminders.first?.components == DateComponents(year: 2028, month: 2, day: 29, hour: 18, minute: 30))
}

@Test func pastAndOffRemindersAreSkipped() {
    let now = at(2026, 10, 9, 12)
    let expired = WarrantySnapshot(itemName: "Headphones", endDate: at(2026, 8, 2))
    let soon = WarrantySnapshot(itemName: "Vacuum", endDate: at(2026, 10, 20))   // 30-day one is past
    let off = WarrantySnapshot(itemName: "Kettle", endDate: at(2027, 1, 1), offsetsDays: [])
    #expect(plan([expired, soon, off], now: now).map(\.id) == ["w.\(soon.id).7"])
    #expect(plan([soon], settings: .init(warranties: false), now: now).isEmpty)
}

@Test func onlyTheSoonestSixtyArePending() {
    let now = at(2026, 1, 1)
    let many = (1...100).map { WarrantySnapshot(itemName: "Item \($0)", endDate: at(2026, 3, 1).addingTimeInterval(Double($0) * 86_400)) }
    let reminders = plan(many, now: now)
    #expect(reminders.count == 60)   // D13: 60 of iOS's 64
    #expect(reminders == reminders.sorted { $0.fireDate < $1.fireDate })
    #expect(reminders.last!.fireDate <= plan(many, now: now, cap: 200)[60].fireDate)
}

@Test func snoozeMovesTheReminderAWeekOn() {
    let now = at(2026, 11, 15, 9, 5)
    let snoozed = now.addingTimeInterval(7 * 86_400)
    let w = WarrantySnapshot(itemName: "Dishwasher", endDate: at(2026, 12, 15), snoozedUntil: snoozed)
    let reminders = plan([w], now: now)
    // The 7-day reminder (Dec 8, 9:00) is after the snooze, so it stays.
    #expect(reminders.map(\.id) == ["w.\(w.id).snooze", "w.\(w.id).7"])
    #expect(reminders[0].fireDate == snoozed && reminders[0].daysLeft == 23)
}

@Test func loansRemindTheMorningTheyAreDue() {
    let now = at(2026, 10, 9, 10)
    let due = LoanSnapshot(itemName: "Drill", person: "Jordan", lentAt: at(2026, 9, 12), dueAt: at(2026, 10, 15))
    let overdue = LoanSnapshot(itemName: "Mixer", person: "Sam", lentAt: at(2026, 8, 30), dueAt: at(2026, 10, 1))
    let reminders = plan([], [due, overdue], now: now)
    #expect(reminders.map(\.id) == ["l.\(due.id)"])
    #expect(reminders[0].fireDate == at(2026, 10, 15, 9) && reminders[0].person == "Jordan")

    var snoozed = overdue
    snoozed.snoozedUntil = at(2026, 10, 16, 10)
    #expect(plan([], [snoozed], now: now).first?.fireDate == at(2026, 10, 16, 10))
    #expect(plan([], [due], settings: .init(loans: false), now: now).isEmpty)
}

// MARK: Reconciling

private actor FakeCenter: NotificationScheduling {
    var pending: [String: String] = [:]
    var added: [String] = []
    var removed: [String] = []

    func pendingReminders() async -> [String: String] { pending }
    func add(_ request: ReminderRequest, text: ReminderText, fingerprint: String) async throws {
        pending[request.id] = fingerprint
        added.append(request.id)
    }
    nonisolated func removeReminders(_ ids: [String]) {
        Task { await self.remove(ids) }
    }
    func remove(_ ids: [String]) {
        for id in ids { pending[id] = nil }
        removed += ids
    }
    func reset() { (added, removed) = ([], []) }
}

private func text(_ request: ReminderRequest) -> ReminderText {
    ReminderText(body: request.isPrivate ? "A private item's warranty ends in \(request.daysLeft) days."
                                         : "Your \(request.itemName) warranty ends in \(request.daysLeft) days.")
}

@Test func reconcilingTouchesOnlyWhatChanged() async {
    let center = FakeCenter()
    let scheduler = ReminderScheduler(center: center)
    let now = at(2026, 10, 9)
    var dishwasher = WarrantySnapshot(itemName: "Dishwasher", endDate: at(2026, 12, 15))
    let lamp = WarrantySnapshot(itemName: "Lamp", endDate: at(2027, 1, 20))

    await scheduler.reconcile(plan([dishwasher, lamp], now: now), text: text)
    #expect(await center.added.count == 4)

    await center.reset()
    await scheduler.reconcile(plan([dishwasher, lamp], now: now), text: text)
    #expect(await center.added.isEmpty)   // nothing changed, nothing touched

    dishwasher.itemName = "Bosch dishwasher"
    await scheduler.reconcile(plan([dishwasher, lamp], now: now), text: text)
    #expect(await center.added.sorted() == ["w.\(dishwasher.id).30", "w.\(dishwasher.id).7"].sorted())

    await center.reset()
    await scheduler.reconcile(plan([lamp], now: now), text: text)
    await Task.yield()
    #expect(await center.added.isEmpty)
    #expect(await center.pending.keys.sorted() == ["w.\(lamp.id).30", "w.\(lamp.id).7"].sorted())
}

@Test func privateItemsAreNotNamed() {
    let w = WarrantySnapshot(itemName: "Engagement ring", isPrivate: true, endDate: at(2026, 12, 15))
    let body = plan([w], now: at(2026, 10, 9)).map { text($0).body }
    #expect(body.allSatisfy { !$0.contains("ring") })
}

// MARK: Snapshots

@MainActor @Test func deletingAnItemDropsItsRemindersAndRestoringBringsThemBack() throws {
    let container = try NookStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let items = ItemService(context: context, blobs: temporaryBlobStore())
    var draft = ItemDraft(currencyCode: "USD")
    draft.name = "Dishwasher"
    draft.purchaseDate = .now
    draft.warranty = .init(lengthMonths: 24)
    let item = try items.create(draft)
    let drill = try items.create({ var d = ItemDraft(); d.name = "Drill"; return d }())
    try items.lend(drill, to: "Jordan", lentAt: .now, dueAt: .now.addingTimeInterval(86_400 * 3), remind: true)
    try context.save()

    #expect(ReminderPlanner.snapshots(in: context).warranties.map(\.itemName) == ["Dishwasher"])
    #expect(ReminderPlanner.snapshots(in: context).loans.map(\.person) == ["Jordan"])

    items.delete([item, drill])
    try context.save()
    #expect(ReminderPlanner.snapshots(in: context).warranties.isEmpty)
    #expect(ReminderPlanner.snapshots(in: context).loans.isEmpty)

    items.restore([item, drill])
    try context.save()
    #expect(ReminderPlanner.snapshots(in: context).warranties.count == 1)
    #expect(ReminderPlanner.snapshots(in: context).loans.count == 1)

    items.markReturned(drill.activeLoan!)
    try context.save()
    #expect(ReminderPlanner.snapshots(in: context).loans.isEmpty)
}
