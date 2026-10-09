import Foundation
import SwiftData
import Testing
@testable import NookKit

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func day(_ y: Int, _ m: Int, _ d: Int, calendar: Calendar = utc) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d))!
}

@Test func endDateIsPurchasePlusLength() {
    #expect(Warranties.endDate(start: day(2025, 3, 14), lengthMonths: 24, calendar: utc) == day(2027, 3, 14))
    // Leap day and month ends follow Calendar: the last day of the shorter month.
    #expect(Warranties.endDate(start: day(2024, 2, 29), lengthMonths: 12, calendar: utc) == day(2025, 2, 28))
    #expect(Warranties.endDate(start: day(2025, 1, 31), lengthMonths: 1, calendar: utc) == day(2025, 2, 28))
}

@Test func daysLeftCountsCalendarDays() {
    #expect(Warranties.daysLeft(until: day(2026, 10, 21), now: day(2026, 10, 9).addingTimeInterval(23 * 3600), calendar: utc) == 12)
    #expect(Warranties.daysLeft(until: day(2026, 10, 1), now: day(2026, 10, 9), calendar: utc) == -8)
}

@Test func statusGroupsMatchR04() {
    let now = day(2026, 10, 9)
    #expect(SearchFilter.status(of: day(2026, 10, 21), now: now, calendar: utc) == .ending)
    #expect(SearchFilter.status(of: day(2027, 3, 14), now: now, calendar: utc) == .active)
    #expect(SearchFilter.status(of: day(2026, 8, 2), now: now, calendar: utc) == .expired)
}

@MainActor
private final class Fixture {
    let container: ModelContainer
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    var context: ModelContext { container.mainContext }
    lazy var items = ItemService(context: context, blobs: temporaryBlobStore(), now: { [unowned self] in self.now })

    init() throws { container = try NookStore.makeContainer(inMemory: true) }

    func item(purchased: Date?, warranty: ItemDraft.WarrantyDraft?) throws -> Item {
        var draft = ItemDraft(currencyCode: "USD")
        draft.name = "Dishwasher"
        draft.purchaseDate = purchased
        draft.warranty = warranty
        return try items.create(draft)
    }
}

@MainActor @Test func aLengthNeedsAPurchaseDate() throws {
    let f = try Fixture()
    let bought = Calendar.current.startOfDay(for: f.now)
    let item = try f.item(purchased: bought, warranty: .init(lengthMonths: 24))
    let warranty = try #require(item.primaryWarranty)
    #expect(warranty.endDate == Warranties.endDate(start: bought, lengthMonths: 24))
    #expect(warranty.startDate == bought && warranty.remindersOn && warranty.kind == .manufacturer)

    // Without a purchase date a length gives no end, so no warranty is kept.
    #expect(try f.item(purchased: nil, warranty: .init(lengthMonths: 24)).warranties?.isEmpty == true)
}

@MainActor @Test func editingTheWarrantyKeepsOneRecord() throws {
    let f = try Fixture()
    let bought = Calendar.current.startOfDay(for: f.now)
    let item = try f.item(purchased: bought, warranty: .init(lengthMonths: 12))
    var draft = ItemDraft(item)
    #expect(draft.warranty?.lengthMonths == 12)

    // An end before the purchase date is allowed (I-02 only warns).
    let early = bought.addingTimeInterval(-30 * 86_400)
    draft.warranty = .init(endDate: early, remindersOn: false)
    try f.items.update(item, from: draft)
    #expect(item.warranties?.count == 1)
    #expect(item.primaryWarranty?.endDate == early && item.primaryWarranty?.lengthMonths == nil)
    #expect(item.primaryWarranty?.remindersOn == false)

    draft.warranty = nil
    try f.items.update(item, from: draft)
    try f.context.save()
    #expect(item.warranties?.isEmpty == true)
    #expect(try f.context.fetchCount(FetchDescriptor<Warranty>()) == 0)
}

@MainActor @Test func lendingTwiceEditsTheSameLoan() throws {
    let f = try Fixture()
    let drill = try f.item(purchased: nil, warranty: nil)
    #expect(throws: ItemService.Failure.noPerson) {
        try f.items.lend(drill, to: "  ", lentAt: f.now, dueAt: nil, remind: true)
    }
    let loan = try f.items.lend(drill, to: " Jordan ", lentAt: f.now, dueAt: nil, remind: true)
    #expect(loan.personName == "Jordan" && drill.activeLoan == loan)
    #expect(loan.remind == false)   // no due date, no reminder (D50)

    let due = f.now.addingTimeInterval(7 * 86_400)
    let same = try f.items.lend(drill, to: "Sam", lentAt: f.now, dueAt: due, remind: true)
    #expect(same == loan && drill.loans?.count == 1 && loan.personName == "Sam" && loan.remind)
}

@MainActor @Test func markReturnedUndoes() throws {
    let f = try Fixture()
    let undo = UndoManager()
    f.context.undoManager = undo
    let drill = try f.item(purchased: nil, warranty: nil)
    let loan = try f.items.lend(drill, to: "Jordan", lentAt: f.now, dueAt: nil, remind: false)
    try f.context.save()
    undo.removeAllActions()

    undo.beginUndoGrouping()
    f.items.markReturned(loan)
    undo.endUndoGrouping()
    try f.context.save()
    #expect(drill.activeLoan == nil && loan.returnedAt == f.now)

    undo.undo()
    try f.context.save()
    #expect(drill.activeLoan == loan && loan.returnedAt == nil)
}
