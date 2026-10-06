import Foundation
import Testing
import SwiftData
@testable import NookKit

@MainActor @Test func aMoveWritesOneEventAndASameplaceMoveWritesNone() throws {
    let container = try NookStore.makeContainer(inMemory: true)   // keep it alive
    let context = container.mainContext
    let rooms = RoomService(context: context)
    let garage = try rooms.addRoom(named: "Garage")
    let shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
    let box = try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
    let drill = Item(name: "Drill")
    context.insert(drill)
    let later = Date(timeIntervalSince1970: 2_000_000_000)
    let locations = LocationService(context: context, now: { later })

    locations.move([drill], to: Location(room: garage, spot: box))
    #expect(drill.room == garage && drill.spot == box)
    #expect(drill.lastConfirmedAt == later)
    let event = try #require(drill.events?.first)
    #expect(event.fromPath == "" && event.toPath == "Garage → Metal shelf → Box 14")
    #expect(event.toSpotID == box.id && event.source == .manual)

    locations.move([drill], to: Location(room: garage, spot: box))   // already there
    #expect(drill.events?.count == 1)

    locations.move([drill], to: nil)
    #expect(drill.room == nil && drill.events?.count == 2)
}

@MainActor private struct Home {
    let container: ModelContainer
    let context: ModelContext
    let garage: Room, kitchen: Room, shelf: Spot, box: Spot, pantry: Spot
    var clock = Date(timeIntervalSince1970: 2_000_000_000)

    init() throws {
        container = try NookStore.makeContainer(inMemory: true)
        context = container.mainContext
        let rooms = RoomService(context: context)
        garage = try rooms.addRoom(named: "Garage")
        kitchen = try rooms.addRoom(named: "Kitchen")
        shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
        box = try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
        pantry = try rooms.addSpot(named: "Pantry", in: kitchen)
        try context.save()
    }

    func item(_ name: String, at location: Location? = nil) -> Item {
        let item = Item(name: name)
        context.insert(item)
        if let location { LocationService(context: context).move([item], to: location) }
        return item
    }

    /// A service whose clock moves on a minute per call, so events have an order.
    mutating func locations() -> LocationService {
        clock += 60
        let now = clock
        return LocationService(context: context, now: { now })
    }
}

@MainActor @Test func aMoveRecordsTheRoomAndSourceAndSkipsItemsAlreadyThere() throws {
    var home = try Home()
    let drill = home.item("Drill", at: Location(room: home.garage, spot: home.shelf))
    let pump = home.item("Pump", at: Location(room: home.kitchen))
    let moved = home.locations().move([drill, pump], to: Location(room: home.kitchen), source: .found)
    #expect(moved == [drill])
    let event = try #require(home.locations().history(of: drill).first)
    #expect(event.toRoomID == home.kitchen.id && event.toSpotID == nil)
    #expect(event.fromPath == "Garage → Metal shelf" && event.toPath == "Kitchen")
    #expect(event.source == .found && pump.events?.count == 1)
}

@MainActor @Test func undoTakesASavedMoveBackAndDropsItsEvent() throws {
    let home = try Home()
    let undo = UndoManager()
    home.context.undoManager = undo
    let drill = home.item("Drill", at: Location(room: home.garage, spot: home.shelf))
    try home.context.save()
    undo.removeAllActions()

    undo.beginUndoGrouping()
    LocationService(context: home.context).move([drill], to: Location(room: home.kitchen, spot: home.pantry))
    undo.endUndoGrouping()
    try home.context.save()
    #expect(drill.spot == home.pantry && drill.events?.count == 2)

    undo.undo()
    try home.context.save()
    #expect(drill.room == home.garage && drill.spot == home.shelf)
    let events = try home.context.fetch(FetchDescriptor<LocationEvent>())
    #expect(events.count == 1 && drill.events?.count == 1)
}

@MainActor @Test func recentsAreNewestFirstDistinctLiveAndSkipTheCurrentPlace() throws {
    var home = try Home()
    let drill = home.item("Drill")
    let shelf = Location(room: home.garage, spot: home.shelf)
    let box = Location(room: home.garage, spot: home.box)
    let pantry = Location(room: home.kitchen, spot: home.pantry)
    let kitchen = Location(room: home.kitchen)
    for place in [shelf, box, pantry, shelf, kitchen] { home.locations().move([drill], to: place) }

    #expect(home.locations().recents() == [kitchen, shelf, pantry, box])
    #expect(home.locations().recents(excluding: kitchen) == [shelf, pantry, box])
    #expect(home.locations().recents(limit: 2) == [kitchen, shelf])

    try RoomService(context: home.context).delete(home.pantry)
    #expect(home.locations().recents() == [kitchen, shelf, box])
}

@MainActor @Test func historyIsNewestFirstAndOutlivesTheSpot() throws {
    var home = try Home()
    let drill = home.item("Drill")
    home.locations().move([drill], to: Location(room: home.kitchen, spot: home.pantry))
    home.locations().move([drill], to: Location(room: home.garage, spot: home.shelf))
    try RoomService(context: home.context).delete(home.pantry)
    let history = home.locations().history(of: drill)
    #expect(history.map(\.toPath) == ["Garage → Metal shelf", "Kitchen → Pantry"])
    #expect(history.first?.fromPath == "Kitchen → Pantry")
}

@MainActor @Test func movingAContainerCarriesItsItemsWithOneEventEach() throws {
    var home = try Home()
    let tent = home.item("Tent", at: Location(room: home.garage, spot: home.box))
    let stove = home.item("Stove", at: Location(room: home.garage, spot: home.box))
    try home.locations().move(home.box, to: Location(room: home.kitchen, spot: home.pantry))
    #expect(home.box.room == home.kitchen && home.box.parent == home.pantry)
    for item in [tent, stove] {
        #expect(item.room == home.kitchen && item.spot == home.box)
        let event = try #require(home.locations().history(of: item).first)
        #expect(event.fromPath == "Garage → Metal shelf → Box 14")
        #expect(event.toPath == "Kitchen → Pantry → Box 14")
    }
    try home.locations().move(home.box, to: Location(room: home.kitchen, spot: home.pantry))   // already there
    #expect(tent.events?.count == 2)

    let bin = try RoomService(context: home.context).addContainer(named: "Bin", in: home.kitchen)
    #expect(throws: LocationService.Failure.containerTooDeep) {
        try home.locations().move(home.box, to: Location(room: home.kitchen, spot: bin))
    }
    #expect(throws: LocationService.Failure.containerTooDeep) {
        try home.locations().move(home.box, to: Location(room: home.garage, spot: home.pantry))   // wrong room
    }
}
