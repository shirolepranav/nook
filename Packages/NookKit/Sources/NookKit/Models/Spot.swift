import Foundation
import SwiftData

extension NookSchemaV1 {
    /// A place in a room ("Top shelf") or a container ("Box 14"). Spots are top-level in a
    /// room; a container sits in the room or inside a spot, never inside another container
    /// (D3, D34). `RoomService` enforces it.
    @Model
    public final class Spot {
        public enum Kind: String, Sendable { case spot, container }

        public var id: UUID = UUID()
        public var name: String = ""
        /// Encoded in the container's QR label as `nook://spot/<qrID>` (D19, P10).
        public var qrID: String = UUID().uuidString
        /// "Packed on" for moving (H-03).
        public var packedAt: Date?
        public var order: Int = 0
        public var createdAt: Date = Date.now
        public var kindRaw: String = Kind.spot.rawValue

        public var room: Room?
        /// The spot a container sits in; nil for spots, and for containers on the room itself.
        public var parent: Spot?
        @Relationship(deleteRule: .cascade, inverse: \Spot.parent) public var children: [Spot]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.spot) public var items: [Item]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.spot) public var photo: Photo?

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .spot }
            set { kindRaw = newValue.rawValue }
        }

        public var isContainer: Bool { kind == .container }

        public init(name: String, kind: Kind = .spot, order: Int) {
            self.name = name
            self.kindRaw = kind.rawValue
            self.order = order
        }
    }
}
