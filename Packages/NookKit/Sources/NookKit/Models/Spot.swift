import Foundation
import SwiftData

extension NookSchemaV1 {
    /// A place in a room ("Top shelf"), or a container when it has a parent spot ("Box 14").
    /// Containers nest one level deep (D3); `SpotService` enforces it.
    @Model
    public final class Spot {
        public var id: UUID = UUID()
        public var name: String = ""
        /// Encoded in the container's QR label as `nook://spot/<qrID>` (D19, P10).
        public var qrID: String = UUID().uuidString
        /// "Packed on" for moving (H-03).
        public var packedAt: Date?
        public var order: Int = 0
        public var createdAt: Date = Date.now

        public var room: Room?
        public var parent: Spot?
        @Relationship(deleteRule: .cascade, inverse: \Spot.parent) public var children: [Spot]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.spot) public var items: [Item]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.spot) public var photo: Photo?

        /// D3: a container is a spot inside another spot.
        public var isContainer: Bool { parent != nil }

        public init(name: String, order: Int) {
            self.name = name
            self.order = order
        }
    }
}
