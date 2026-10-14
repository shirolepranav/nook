import Foundation
import SwiftData
import Testing
@testable import NookKit

/// The Free tier's limits (D9, D58): 25 items and 3 active warranty reminders, enforced in
/// `ItemService`, never locking away what's already there.
@MainActor
private final class Fixture {
    let container: ModelContainer
    var isPro = false
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var context: ModelContext { container.mainContext }
    lazy var items = ItemService(context: context, blobs: temporaryBlobStore(), now: { [unowned self] in self.now },
                                 isPro: { [unowned self] in self.isPro })

    init() throws { container = try NookStore.makeContainer(inMemory: true) }

    func draft(_ name: String, warrantyDays: Double? = nil, reminders: Bool = true) -> ItemDraft {
        var draft = ItemDraft(currencyCode: "USD", location: nil)
        draft.name = name
        if let warrantyDays {
            draft.warranty = .init(endDate: now.addingTimeInterval(warrantyDays * 86_400), remindersOn: reminders)
        }
        return draft
    }

    @discardableResult
    func fill(_ count: Int) throws -> [Item] {
        try (0..<count).map { try items.create(draft("Thing \($0)")) }
    }
}

@MainActor @Test func theTwentySixthItemNeedsPro() throws {
    let f = try Fixture()
    try f.fill(25)
    #expect(throws: ItemService.Failure.itemLimit) { try f.items.create(f.draft("One more")) }
    f.isPro = true
    #expect(try f.items.create(f.draft("One more")).name == "One more")
}

@MainActor @Test func duplicateCountsAsAnAdd() throws {
    let f = try Fixture()
    let items = try f.fill(25)
    #expect(throws: ItemService.Failure.itemLimit) { try f.items.duplicate(items[0]) }
}

@MainActor @Test func aBatchOverTheLimitIsCaughtBeforeAnyCreate() throws {
    let f = try Fixture()
    try f.fill(22)
    try f.items.checkCanAdd(3)
    #expect(throws: ItemService.Failure.itemLimit) { try f.items.checkCanAdd(4) }
    #expect(try f.context.fetchCount(FetchDescriptor<Item>()) == 22)
}

@MainActor @Test func deletedItemsDontCountAndRestoreIsNeverBlocked() throws {
    let f = try Fixture()
    let items = try f.fill(25)
    f.items.delete([items[0]])
    try f.items.create(f.draft("Fits again"))
    // Back at 25 live items; restoring the deleted one is the user's own data (PRD §7).
    f.items.restore([items[0]])
    #expect(items[0].deletedAt == nil)
    #expect(try f.context.fetchCount(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil })) == 26)
}

@MainActor @Test func losingProKeepsEverythingAndOnlyBlocksNewAdds() throws {
    let f = try Fixture()
    f.isPro = true
    let items = try f.fill(30)
    f.isPro = false   // a refund
    #expect(throws: ItemService.Failure.itemLimit) { try f.items.create(f.draft("New")) }
    var draft = ItemDraft(items[29])
    draft.name = "Renamed"
    try f.items.update(items[29], from: draft)
    #expect(items[29].name == "Renamed")
}

@MainActor @Test func theFourthActiveReminderNeedsPro() throws {
    let f = try Fixture()
    for index in 0..<3 { try f.items.create(f.draft("Warranty \(index)", warrantyDays: 100)) }
    #expect(try f.items.activeReminderCount() == 3)
    #expect(throws: ItemService.Failure.reminderLimit) { try f.items.create(f.draft("Fourth", warrantyDays: 100)) }
    // Reminders off, or already ended, don't count and aren't blocked.
    try f.items.create(f.draft("Quiet", warrantyDays: 100, reminders: false))
    try f.items.create(f.draft("Ended", warrantyDays: -10))
    #expect(try f.items.activeReminderCount() == 3)
}

@MainActor @Test func deletedAndOffRemindersFreeASlot() throws {
    let f = try Fixture()
    let first = try f.items.create(f.draft("A", warrantyDays: 100))
    let second = try f.items.create(f.draft("B", warrantyDays: 100))
    try f.items.create(f.draft("C", warrantyDays: 100))
    let quiet = try f.items.create(f.draft("D", warrantyDays: 100, reminders: false))
    #expect(throws: ItemService.Failure.reminderLimit) { try f.items.setReminders(quiet.primaryWarranty!, on: true) }
    f.items.delete([first])
    try f.items.setReminders(quiet.primaryWarranty!, on: true)
    try f.items.setReminders(second.primaryWarranty!, on: false)
    #expect(try f.items.activeReminderCount() == 2)
}

@MainActor @Test func editingAnItemWithItsReminderOnIsNotAnAdd() throws {
    let f = try Fixture()
    let items = try (0..<3).map { try f.items.create(f.draft("W \($0)", warrantyDays: 100)) }
    var draft = ItemDraft(items[0])
    draft.notes = "Under the sink"
    try f.items.update(items[0], from: draft)
    #expect(items[0].notes == "Under the sink")
}

@Test func limitsAreTwentyFiveAndThree() {
    #expect(EntitlementStore.canAddItems(isPro: false, existing: 24, adding: 1))
    #expect(!EntitlementStore.canAddItems(isPro: false, existing: 25, adding: 1))
    #expect(EntitlementStore.canAddItems(isPro: true, existing: 5_000, adding: 30))
    #expect(EntitlementStore.canAddReminder(isPro: false, active: 2))
    #expect(!EntitlementStore.canAddReminder(isPro: false, active: 3))
}
