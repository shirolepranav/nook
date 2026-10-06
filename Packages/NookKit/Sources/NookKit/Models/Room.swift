import Foundation
import SwiftData

extension NookSchemaV1 {
    /// A room in the home (F1). Holds spots, and items placed straight in the room.
    @Model
    public final class Room {
        public var id: UUID = UUID()
        public var name: String = ""
        /// SF Symbol name.
        public var symbol: String = "square.grid.2x2"
        /// A `RoomColor` raw value (NookUI); NookKit stays UI-free.
        public var colorKey: String = "stone"
        /// Position on Home; relationships can't be ordered in CloudKit (D8).
        public var order: Int = 0
        public var createdAt: Date = Date.now

        // A room owns its spots; items survive a room's deletion and are rehomed or sent to
        // Recently Deleted by the caller first (D28, P3).
        @Relationship(deleteRule: .cascade, inverse: \Spot.room) public var spots: [Spot]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.room) public var items: [Item]? = []

        public init(name: String, symbol: String, colorKey: String, order: Int) {
            self.name = name
            self.symbol = symbol
            self.colorKey = colorKey
            self.order = order
        }
    }
}
