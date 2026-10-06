import Foundation
import Testing
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
