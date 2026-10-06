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

/// The only writer of an item's location (CLAUDE.md hard rule, 04 §6): moves, the Move
/// picker's recents (I-04) and location history (I-05). Moves undo through the context's
/// `UndoManager`, so the toast's Undo, ⌘Z and shake take them back (04 §9, D45).
@MainActor
public struct LocationService {
    public enum Failure: Error, Equatable {
        /// D3, D34: a container goes on a room or in a spot, never in another container.
        case containerTooDeep
    }

    let context: ModelContext
    let now: () -> Date

    public init(context: ModelContext, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.now = now
    }

    /// Moves items and records one `LocationEvent` each. A move to where an item already is
    /// changes nothing. `nil` takes items out of every room (a restore whose room is gone).
    /// Returns the items that actually moved.
    @discardableResult
    public func move(_ items: [Item], to location: Location?, source: LocationEvent.Source = .manual) -> [Item] {
        let moved = items.filter { item in
            let from = Location(of: item)
            return from?.room.id != location?.room.id || from?.spot?.id != location?.spot?.id
        }
        for item in moved {
            record(item, from: Location(of: item)?.path ?? "", fromSpotID: item.spot?.id, to: location, source: source)
            item.room = location?.room
            item.spot = location?.spot
        }
        return moved
    }

    /// Moves a container, and everything in it, onto a room or into one of its spots (H-03).
    /// Each item inside gets its own history entry, since its place changed too.
    public func move(_ container: Spot, to location: Location) throws {
        guard container.isContainer else { throw Failure.containerTooDeep }
        if let spot = location.spot, spot.isContainer || spot.room?.id != location.room.id {
            throw Failure.containerTooDeep
        }
        guard container.room?.id != location.room.id || container.parent?.id != location.spot?.id else { return }
        let items = container.items ?? []
        let fromPaths = items.map { Location(of: $0)?.path ?? "" }
        let siblings = (location.spot?.children ?? (location.room.spots ?? []).filter { $0.isContainer && $0.parent == nil })
            .filter { $0.id != container.id }
        container.room = location.room
        container.parent = location.spot
        container.order = (siblings.map(\.order).max() ?? -1) + 1
        let to = Location(room: location.room, spot: container)
        for (item, fromPath) in zip(items, fromPaths) {
            record(item, from: fromPath, fromSpotID: container.id, to: to, source: .manual)
            item.room = location.room
        }
    }

    /// Up to `limit` places moved to most recently, newest first, that still exist; never
    /// `excluding` (the place the item is already in). Additions count, so a fresh item's
    /// place is already a recent.
    public func recents(limit: Int = 5, excluding: Location? = nil) -> [Location] {
        // ponytail: a fixed window of 50 events; widen it if recents come up short.
        var descriptor = FetchDescriptor<LocationEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 50
        let events = (try? context.fetch(descriptor)) ?? []
        let rooms = Dictionary(((try? context.fetch(FetchDescriptor<Room>())) ?? []).map { ($0.id, $0) },
                               uniquingKeysWith: { a, _ in a })
        let spots = Dictionary(((try? context.fetch(FetchDescriptor<Spot>())) ?? []).map { ($0.id, $0) },
                               uniquingKeysWith: { a, _ in a })
        var seen = Set<Location>(), result: [Location] = []
        for event in events where result.count < limit {
            let location: Location?
            if let spotID = event.toSpotID {
                location = spots[spotID].flatMap { spot in spot.room.map { Location(room: $0, spot: spot) } }
            } else {
                location = event.toRoomID.flatMap { rooms[$0] }.map { Location(room: $0) }
            }
            guard let location, location != excluding, seen.insert(location).inserted else { continue }
            result.append(location)
        }
        return result
    }

    /// The item's moves, newest first (I-05). Paths are text, so deleted places still read.
    public func history(of item: Item) -> [LocationEvent] {
        (item.events ?? []).sorted { $0.date > $1.date }
    }

    private func record(_ item: Item, from fromPath: String, fromSpotID: UUID?, to location: Location?,
                        source: LocationEvent.Source) {
        let event = LocationEvent(fromPath: fromPath, toPath: location?.path ?? "", source: source)
        (event.fromSpotID, event.toSpotID, event.toRoomID, event.date) =
            (fromSpotID, location?.spot?.id, location?.room.id, now())
        context.insert(event)
        event.item = item
        item.lastConfirmedAt = now()
    }
}
