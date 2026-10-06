import Foundation
import Testing
import SwiftData
@testable import NookKit

/// A small home: Garage with a Workbench and Box 14 (packed) on a Metal shelf, an Office desk.
@MainActor private struct Home {
    let container: ModelContainer
    let context: ModelContext
    let garage: Room, office: Room, bench: Spot, shelf: Spot, box: Spot, desk: Spot

    init() throws {
        container = try NookStore.makeContainer(inMemory: true)
        context = container.mainContext
        let rooms = RoomService(context: context)
        garage = try rooms.addRoom(named: "Garage")
        bench = try rooms.addSpot(named: "Workbench", in: garage)
        shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
        box = try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
        office = try rooms.addRoom(named: "Office")
        desk = try rooms.addSpot(named: "Desk", in: office)
    }

    @discardableResult
    func add(_ name: String, at location: Location?, isPrivate: Bool = false, quantity: Int = 1) throws -> Item {
        var draft = ItemDraft(location: location)
        (draft.name, draft.isPrivate, draft.quantity) = (name, isPrivate, quantity)
        return try ItemService(context: context).create(draft)
    }

    var index: SearchIndex {
        try? context.save()
        return SearchIndex(docs: SearchSnapshot.docs(in: ModelContext(container)))
    }

    func ask(_ text: String) -> FindAnswer? {
        let question = FindQuestion(text)
        return FindService(context: context).answer(question, hits: index.search(terms: question.terms))
    }
}

@MainActor @Test func snapshotsCarryPathsReceiptsLoansAndWarranties() throws {
    let home = try Home()
    let drill = try home.add("Cordless drill", at: Location(room: home.garage, spot: home.bench))
    drill.serial = "SN-4471"
    let receipt = Receipt(fileName: "r.heic", kind: .image)
    home.context.insert(receipt); receipt.item = drill; receipt.extractedText = "Hardware store total 159.00"
    let loan = Loan(personName: "Jordan"); home.context.insert(loan); loan.item = drill
    let warranty = Warranty(kind: .manufacturer); home.context.insert(warranty); warranty.item = drill
    warranty.endDate = Date(timeIntervalSince1970: 2_000_000_000)
    try home.add("Old thing", at: nil).deletedAt = .now

    try home.context.save()
    let docs = SearchSnapshot.docs(in: ModelContext(home.container))
    let doc = try #require(docs.first { $0.name == "Cordless drill" })
    #expect(doc.path == "Garage → Workbench" && doc.roomID == home.garage.id)
    #expect(doc.receiptText.contains("159.00") && doc.codes == ["SN-4471"])
    #expect(doc.isLent && doc.warrantyEnd == warranty.endDate)
    #expect(!docs.contains { $0.name == "Old thing" })                       // Recently Deleted is left out
    #expect(docs.first { $0.name == "Box 14" }?.kind == .container)
    #expect(docs.first { $0.name == "Box 14" }?.path == "Garage → Metal shelf")

    try RoomService(context: home.context).rename(home.garage, to: "Workshop")   // paths are never stale
    try home.context.save()
    #expect(SearchSnapshot.docs(in: ModelContext(home.container)).first { $0.name == "Cordless drill" }?.path
            == "Workshop → Workbench")
}

@MainActor @Test func aTypoStillAnswersWithTheLocation() throws {
    let home = try Home()
    let passport = try home.add("Passport", at: Location(room: home.office, spot: home.desk))
    #expect(home.ask("pasport") == .location(item: passport.id))
    #expect(home.ask("Where are the passports?") == .location(item: passport.id))
    #expect(home.ask("skis") == nil)                                         // no record, no answer
}

@MainActor @Test func lentPackedAndQuantityAnswers() throws {
    let home = try Home()
    let drill = try home.add("Cordless drill", at: Location(room: home.garage, spot: home.bench))
    let loan = Loan(personName: "Jordan"); home.context.insert(loan); loan.item = drill
    #expect(home.ask("Who has my drill?") == .lent(item: drill.id, person: "Jordan", since: loan.lentAt, due: nil))
    #expect(home.ask("drill")?.itemID == drill.id)
    loan.returnedAt = .now
    #expect(home.ask("Who has my drill?") == nil)
    #expect(home.ask("drill") == .location(item: drill.id))

    let packed = Date(timeIntervalSince1970: 1_780_000_000)
    home.box.packedAt = packed
    let bedding = try home.add("Winter bedding", at: Location(room: home.garage, spot: home.box))
    #expect(home.ask("Where’s the winter bedding?") == .packed(item: bedding.id, container: home.box.id, on: packed))

    let batteries = try home.add("AA batteries", at: Location(room: home.office, spot: home.desk), quantity: 2)
    #expect(home.ask("Do I have any AA batteries?") == .quantity(item: batteries.id, count: 2))
}

@MainActor @Test func roomContentsAreGroupedBySpot() throws {
    let home = try Home()
    try home.add("Drill", at: Location(room: home.garage, spot: home.bench))
    try home.add("Level", at: Location(room: home.garage, spot: home.bench))
    try home.add("Tent", at: Location(room: home.garage, spot: home.box))      // in a box on the shelf
    try home.add("Bike pump", at: Location(room: home.garage))
    try home.add("Secret", at: Location(room: home.garage, spot: home.bench), isPrivate: true)
    guard case .contents(let place, let total, let groups) = home.ask("What’s in the garage?") else {
        Issue.record("expected a contents answer"); return
    }
    #expect(place == home.garage.id && total == 5)
    #expect(groups.map(\.name) == [nil, "Workbench", "Metal shelf"])
    #expect(groups.map(\.count) == [1, 3, 1])
    #expect(groups[1].itemNames == ["Drill", "Level"])                          // the private one isn't named
    // A plain search for a place answers the same way.
    #expect(home.ask("garage").map { if case .contents = $0 { true } else { false } } == true)
}

@MainActor @Test func privateItemsNeverAnswer() throws {
    let home = try Home()
    try home.add("Grandma’s ring", at: Location(room: home.office, spot: home.desk), isPrivate: true)
    #expect(home.ask("ring") == nil)
    #expect(home.index.search("ring").first?.isPrivate == true)                // still listed, masked by the UI
}

@MainActor @Test func savedSearchesKeepOrderAndFilters() throws {
    let home = try Home()
    let find = FindService(context: home.context)
    var filter = SearchFilter()
    filter.roomIDs = [home.garage.id]
    let camping = find.save(name: " Camping gear ", query: "tent", filter: filter)
    let kitchen = find.save(name: "", query: "mixer", filter: SearchFilter())
    #expect(camping.name == "Camping gear" && kitchen.name == "mixer")         // the words name an unnamed one
    #expect(camping.filter == filter && kitchen.filterData == nil)

    find.move(find.savedSearches(), from: [1], to: 0)
    #expect(find.savedSearches().map(\.name) == ["mixer", "Camping gear"])
    find.rename(kitchen, to: "  ")
    #expect(kitchen.name == "mixer")
    find.rename(kitchen, to: "Kitchen")
    find.delete(camping)
    try home.context.save()
    #expect(find.savedSearches().map(\.name) == ["Kitchen"])
}
