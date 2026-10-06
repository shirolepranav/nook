import Foundation
import SwiftData

/// Where an item is: a room, and optionally a spot or container in it.
public struct Location: Hashable {
    public let room: Room
    public let spot: Spot?

    public init(room: Room, spot: Spot? = nil) {
        self.room = room
        self.spot = spot
    }

    /// The item's current place, or nil when it has none.
    public init?(of item: Item) {
        guard let room = item.room else { return nil }
        self.init(room: room, spot: item.spot)
    }

    /// "Garage → Metal shelf → Box 14" (I-01 breadcrumb).
    public var path: String { names.joined(separator: " → ") }

    /// Room, then the spot a container sits in, then the spot or container.
    public var names: [String] {
        [room.name] + [spot?.parent?.name, spot?.name].compactMap { $0 }
    }
}

/// The only writer of an item's location (CLAUDE.md hard rule, 04 §6). P3 ships this minimal
/// version for the editor (D38); P4 adds the picker, recents and history on top.
@MainActor
public struct LocationService {
    let context: ModelContext
    let now: () -> Date

    public init(context: ModelContext, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.now = now
    }

    /// Moves items and records one `LocationEvent` each. A move to where an item already is
    /// changes nothing. `nil` takes items out of every room (a restore whose room is gone).
    public func move(_ items: [Item], to location: Location?, source: LocationEvent.Source = .manual) {
        for item in items {
            let from = Location(of: item)
            guard from?.room.id != location?.room.id || from?.spot?.id != location?.spot?.id else { continue }
            let event = LocationEvent(fromPath: from?.path ?? "", toPath: location?.path ?? "", source: source)
            (event.fromSpotID, event.toSpotID, event.date) = (from?.spot?.id, location?.spot?.id, now())
            context.insert(event)
            event.item = item
            item.room = location?.room
            item.spot = location?.spot
            item.lastConfirmedAt = now()
        }
    }
}
