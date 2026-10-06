import Foundation
import SwiftData
import Testing
@testable import NookKit

@MainActor
private func service() throws -> (RoomService, ModelContext) {
    let context = ModelContext(try NookStore.makeContainer(inMemory: true))
    return (RoomService(context: context), context)
}

@MainActor @Test func presetRoomsGetTheirSymbolAndColor() throws {
    let (rooms, _) = try service()
    let kitchen = try rooms.addRoom(named: "  kitchen ")
    #expect(kitchen.name == "kitchen")          // trimmed, the user's casing kept
    #expect(kitchen.symbol == "fork.knife")
    #expect(kitchen.colorKey == "butter")
}

@MainActor @Test func customRoomsTakeTheLeastUsedColor() throws {
    let (rooms, _) = try service()
    try rooms.addRoom(named: "Kitchen")          // butter
    let studio = try rooms.addRoom(named: "Studio")
    #expect(studio.symbol == "square.grid.2x2")
    #expect(studio.colorKey == "clay")          // first unused color
}

@MainActor @Test func blankNamesAreRejected() throws {
    let (rooms, _) = try service()
    #expect(throws: RoomService.Failure.emptyName) { try rooms.addRoom(named: "   ") }
    let room = try rooms.addRoom(named: "Office")
    #expect(throws: RoomService.Failure.emptyName) { try rooms.addSpot(named: "", in: room) }
}

@MainActor @Test func roomsKeepTheirOrder() throws {
    let (rooms, _) = try service()
    let a = try rooms.addRoom(named: "A")
    let b = try rooms.addRoom(named: "B")
    let c = try rooms.addRoom(named: "C")
    #expect(try rooms.rooms().map(\.name) == ["A", "B", "C"])
    rooms.reorder([c, a, b])                    // H-07
    #expect(try rooms.rooms().map(\.name) == ["C", "A", "B"])
    #expect([c, a, b].map(\.order) == [0, 1, 2])
}

@MainActor @Test func containersNestOneLevelOnly() throws {
    let (rooms, _) = try service()
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Shelf", in: garage)
    let box = try rooms.addSpot(named: "Box 14", in: garage, inside: shelf)
    #expect(box.isContainer)
    #expect(rooms.containers(in: shelf).map(\.name) == ["Box 14"])
    #expect(rooms.spots(in: garage).map(\.name) == ["Shelf"])   // containers aren't top-level
    // D3
    #expect(throws: RoomService.Failure.containerTooDeep) {
        try rooms.addSpot(named: "Bag", in: garage, inside: box)
    }
}

@MainActor @Test func spotsKeepTheirOrder() throws {
    let (rooms, _) = try service()
    let kitchen = try rooms.addRoom(named: "Kitchen")
    let counter = try rooms.addSpot(named: "Counter", in: kitchen)
    let pantry = try rooms.addSpot(named: "Pantry", in: kitchen)
    let drawer = try rooms.addSpot(named: "Top drawer", in: kitchen)
    #expect(rooms.spots(in: kitchen).map(\.name) == ["Counter", "Pantry", "Top drawer"])
    rooms.reorder([drawer, counter, pantry])
    #expect(rooms.spots(in: kitchen).map(\.name) == ["Top drawer", "Counter", "Pantry"])
}

@MainActor @Test func roomsWithItemsCantBeDeleted() throws {
    let (rooms, context) = try service()
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Shelf", in: garage)
    let box = try rooms.addSpot(named: "Box", in: garage, inside: shelf)
    let drill = Item(name: "Drill")
    context.insert(drill)
    drill.room = garage
    drill.spot = box
    // D28: the items have to go somewhere first.
    #expect(throws: RoomService.Failure.hasItems) { try rooms.delete(garage) }
    #expect(throws: RoomService.Failure.hasItems) { try rooms.delete(shelf) }
    // Items already in Recently Deleted don't block it.
    drill.deletedAt = .now
    try rooms.delete(garage)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<Room>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Spot>()) == 0)
}

@MainActor @Test func threeSpotsTakeFourCalls() throws {
    // F1 / S2: a room with 3 spots is four calls; the UI test times the 30-second target.
    let (rooms, context) = try service()
    let office = try rooms.addRoom(named: "Office")
    for name in ["Desk", "Shelf", "Closet"] { try rooms.addSpot(named: name, in: office) }
    try context.save()
    #expect(rooms.spots(in: office).count == 3)
}
