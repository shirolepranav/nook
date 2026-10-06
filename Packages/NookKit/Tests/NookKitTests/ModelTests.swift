import Foundation
import SwiftData
import Testing
@testable import NookKit

@MainActor
private func freshContext() throws -> ModelContext {
    ModelContext(try NookStore.makeContainer(inMemory: true))
}

@MainActor @Test func defaultsMatchTheDataModel() throws {
    let context = try freshContext()
    let item = Item(name: "Drill")
    let warranty = Warranty(kind: .extended)
    context.insert(item)
    context.insert(warranty)
    // 04 §4
    #expect(item.quantity == 1)
    #expect(item.isPrivate == false)
    #expect(item.deletedAt == nil)
    #expect(warranty.reminderOffsetsDays == [30, 7])
    #expect(warranty.kind == .extended)
    #expect(Loan(personName: "Jordan").remind)
}

@MainActor @Test func deletingARoomDeletesItsSpotsAndContainersButNotItsItems() throws {
    let context = try freshContext()
    let room = Room(name: "Garage", symbol: "car", colorKey: "stone", order: 0)
    let shelf = Spot(name: "Shelf", order: 0)
    let box = Spot(name: "Box 14", order: 0)
    let drill = Item(name: "Drill")
    context.insert(room)
    shelf.room = room
    box.room = room
    box.parent = shelf
    drill.room = room
    drill.spot = box
    try context.save()

    context.delete(room)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Spot>()) == 0)
    // Items are never lost with a room: P3 rehomes them or sends them to Recently Deleted first.
    let items = try context.fetch(FetchDescriptor<Item>())
    #expect(items.map(\.name) == ["Drill"])
    #expect(items.first?.room == nil)
}

@MainActor @Test func deletingAnItemDeletesWhatItOwns() throws {
    let context = try freshContext()
    let item = Item(name: "Dishwasher")
    context.insert(item)
    item.photos = [Photo(fileName: "a.heic")]
    item.receipts = [Receipt(fileName: "r.pdf", kind: .pdf)]
    item.warranties = [Warranty(kind: .manufacturer)]
    item.events = [LocationEvent(fromPath: "", toPath: "Kitchen", source: .manual)]
    item.loans = [Loan(personName: "Sam")]
    try context.save()

    context.delete(item)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Receipt>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Warranty>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<LocationEvent>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Loan>()) == 0)
}

@Test func storedEnumsFallBackSafely() {
    // Enums are stored as raw strings (D8); an unknown value from a newer app version
    // reads as the default instead of crashing.
    let receipt = Receipt(fileName: "x", kind: .image)
    receipt.kindRaw = "hologram"
    #expect(receipt.kind == .image)
}
