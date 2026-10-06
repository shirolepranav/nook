#if DEBUG
import Foundation
import SwiftData

/// In-memory stores for previews and UI tests (04 §11). `small` is a lived-in home: four
/// rooms with spots and one container.
@MainActor
public enum PreviewStore {
    public enum Size: String, Sendable {
        case empty, small, many
    }

    public static func seeded(_ size: Size) -> ModelContainer {
        do {
            let container = try NookStore.makeContainer(inMemory: true)
            switch size {
            case .empty: break
            case .small: try seedSmall(container.mainContext)
            case .many: try seedMany(container.mainContext)
            }
            return container
        } catch {
            fatalError("Preview store failed: \(error)")   // debug builds only
        }
    }

    private static func seedSmall(_ context: ModelContext) throws {
        let rooms = RoomService(context: context)
        let kitchen = try rooms.addRoom(named: "Kitchen")
        for spot in ["Counter", "Pantry", "Top drawer"] { try rooms.addSpot(named: spot, in: kitchen) }
        let living = try rooms.addRoom(named: "Living room")
        try rooms.addSpot(named: "Bookshelf", in: living)
        try rooms.addContainer(named: "Blue bin", in: living)
        let bedroom = try rooms.addRoom(named: "Bedroom")
        let wardrobe = try rooms.addSpot(named: "Wardrobe", in: bedroom)
        try rooms.addContainer(named: "Shoe box", in: bedroom, inside: wardrobe)
        let garage = try rooms.addRoom(named: "Garage")
        let shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
        try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
        try context.save()
    }

    private static func seedMany(_ context: ModelContext) throws {
        let rooms = RoomService(context: context)
        for number in 1...54 { try rooms.addRoom(named: "Room \(number)") }
        let long = try rooms.addRoom(named: "The spare bedroom at the very end of the upstairs hallway")
        try rooms.addSpot(named: "The tall wardrobe with the sliding mirror doors on the left", in: long)
        try context.save()
    }
}
#endif
