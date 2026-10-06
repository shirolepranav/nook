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

@MainActor @Test func containersSitInARoomOrASpotButNotInAContainer() throws {
    let (rooms, _) = try service()
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Shelf", in: garage)
    let box = try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
    let bin = try rooms.addContainer(named: "Blue bin", in: garage)        // on the floor (D34)
    #expect(box.isContainer && bin.isContainer)
    #expect(rooms.containers(in: shelf).map(\.name) == ["Box 14"])
    #expect(rooms.looseContainers(in: garage).map(\.name) == ["Blue bin"])
    #expect(rooms.spots(in: garage).map(\.name) == ["Shelf"])            // containers aren't spots
    // D3, D34: never inside another container, never across rooms.
    #expect(throws: RoomService.Failure.containerTooDeep) {
        try rooms.addContainer(named: "Bag", in: garage, inside: box)
    }
    let attic = try rooms.addRoom(named: "Attic")
    #expect(throws: RoomService.Failure.containerTooDeep) {
        try rooms.addContainer(named: "Crate", in: attic, inside: shelf)
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
    let box = try rooms.addContainer(named: "Box", in: garage, inside: shelf)
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

@MainActor @Test func containersMoveAndSpotsChangeKindWithinTheRules() throws {
    let (rooms, _) = try service()
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Shelf", in: garage)
    let bin = try rooms.addContainer(named: "Blue bin", in: garage)
    let box = try rooms.addContainer(named: "Box", in: garage, inside: shelf)

    try rooms.place(bin, inside: shelf)                  // floor → shelf
    #expect(rooms.containers(in: shelf).map(\.name) == ["Box", "Blue bin"])
    try rooms.place(bin, inside: nil)                    // back on the floor
    #expect(rooms.looseContainers(in: garage).map(\.name) == ["Blue bin"])
    #expect(throws: RoomService.Failure.containerTooDeep) { try rooms.place(box, inside: bin) }
    #expect(throws: RoomService.Failure.containerTooDeep) { try rooms.place(shelf, inside: nil) }  // not a container

    // A spot holding containers can't become one; an empty one can.
    #expect(throws: RoomService.Failure.containerTooDeep) { try rooms.setKind(of: shelf, to: .container) }
    let crate = try rooms.addSpot(named: "Crate", in: garage)
    try rooms.setKind(of: crate, to: .container)
    #expect(rooms.looseContainers(in: garage).map(\.name) == ["Blue bin", "Crate"])
    try rooms.setKind(of: box, to: .spot)                // comes out onto the room as a spot
    #expect(box.parent == nil)
    #expect(rooms.spots(in: garage).map(\.name) == ["Shelf", "Box"])
}

/// D35: a saved delete undoes, and the room, its spots and nested containers survive the
/// next save (SwiftData's own undo loses them there).
@MainActor @Test func undoingASavedDeleteBringsTheRoomBack() throws {
    let container = try NookStore.makeContainer(inMemory: true)   // keep it alive
    let context = container.mainContext
    let rooms = RoomService(context: context)
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
    let box = try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
    let (garageID, qrID) = (garage.id, box.qrID)
    try context.save()
    let undo = UndoManager()
    context.undoManager = undo

    try rooms.delete(garage)
    try context.save()
    RunLoop.main.run(until: .now + 0.1)   // closes the undo group, as the app's run loop does
    #expect(try rooms.rooms().isEmpty)

    undo.undo()
    try context.save()
    let restored = try #require(try rooms.rooms().first)
    #expect(restored.id == garageID)
    let spot = try #require(rooms.spots(in: restored).first)
    #expect(spot.name == "Metal shelf")
    #expect(rooms.containers(in: spot).map(\.qrID) == [qrID])   // QR labels keep working
}

/// D28: a room's items move to another room, or go to Recently Deleted, and one Undo puts
/// the room back with its items where they were.
@MainActor @Test func deletingARoomRehomesItsItemsAndUndoesInOneStep() throws {
    let container = try NookStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let rooms = RoomService(context: context)
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Shelf", in: garage)
    let attic = try rooms.addRoom(named: "Attic")
    let drill = Item(name: "Drill"), saw = Item(name: "Saw")
    for item in [drill, saw] { context.insert(item) }
    LocationService(context: context).move([drill], to: Location(room: garage, spot: shelf))
    LocationService(context: context).move([saw], to: Location(room: garage))
    try context.save()
    let undo = UndoManager()
    context.undoManager = undo

    try rooms.delete(garage, rehoming: .recentlyDeleted)
    try context.save()
    RunLoop.main.run(until: .now + 0.1)
    #expect(drill.deletedAt != nil && saw.deletedAt != nil)

    undo.undo()
    try context.save()
    let restored = try #require(try rooms.rooms().first { $0.name == "Garage" })
    #expect(drill.deletedAt == nil && saw.deletedAt == nil)
    #expect(drill.room == restored && drill.spot?.name == "Shelf" && saw.room == restored)

    try rooms.delete(restored, rehoming: .move(to: Location(room: attic)))
    try context.save()
    #expect(drill.room == attic && drill.spot == nil && drill.deletedAt == nil)
}
