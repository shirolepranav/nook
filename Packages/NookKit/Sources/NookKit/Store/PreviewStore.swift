#if DEBUG
import Foundation
import SwiftData

/// In-memory stores for previews and UI tests (04 §11). `small` is a lived-in home: four
/// rooms with spots and one container.
@MainActor
public enum PreviewStore {
    public enum Size: String, Sendable {
        case empty, small
    }

    public static func seeded(_ size: Size) -> ModelContainer {
        do {
            let container = try NookStore.makeContainer(inMemory: true)
            if size == .small { try seedSmall(container.mainContext) }
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
        let bedroom = try rooms.addRoom(named: "Bedroom")
        let wardrobe = try rooms.addSpot(named: "Wardrobe", in: bedroom)
        try rooms.addSpot(named: "Top shelf", in: bedroom, inside: wardrobe)
        let garage = try rooms.addRoom(named: "Garage")
        let shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
        try rooms.addSpot(named: "Box 14", in: garage, inside: shelf)
        try context.save()
    }
}
#endif
