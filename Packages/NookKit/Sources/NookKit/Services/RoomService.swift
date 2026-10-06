import Foundation
import SwiftData

/// Rooms, spots and containers (F1). Every change to them goes through here, so the rules
/// hold everywhere: names aren't blank, order stays dense, containers nest one level (D3),
/// and a room with items can't be deleted until they're rehomed (D28, P3).
/// Undo comes from the context's `UndoManager`, which the app ties to the window (04 §9).
@MainActor
public struct RoomService {
    public enum Failure: Error, Equatable {
        case emptyName
        /// D3: a container can't hold another container.
        case containerTooDeep
        /// Items must be moved or sent to Recently Deleted first (D28).
        case hasItems
    }

    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Rooms

    public func rooms() throws -> [Room] {
        try context.fetch(FetchDescriptor<Room>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)]))
    }

    /// Adds a room at the end. Symbol and color come from the preset when the name matches
    /// one (O-02), unless given.
    @discardableResult
    public func addRoom(named name: String, symbol: String? = nil, colorKey: String? = nil) throws -> Room {
        let name = try validated(name)
        let existing = try rooms()
        let style = RoomPreset.style(for: name, existingColorKeys: existing.map(\.colorKey))
        let room = Room(name: name, symbol: symbol ?? style.symbol, colorKey: colorKey ?? style.colorKey,
                        order: (existing.last?.order ?? -1) + 1)
        context.insert(room)
        return room
    }

    public func rename(_ room: Room, to name: String) throws {
        room.name = try validated(name)
    }

    /// Saves the order shown in Arrange rooms (H-07).
    public func reorder(_ rooms: [Room]) {
        for (index, room) in rooms.enumerated() where room.order != index {
            room.order = index
        }
    }

    /// Deletes a room and its spots. Throws while it still holds items that aren't deleted.
    public func delete(_ room: Room) throws {
        let liveItems = (room.items ?? []) + (room.spots ?? []).flatMap(allItems)
        guard liveItems.allSatisfy({ $0.deletedAt != nil }) else { throw Failure.hasItems }
        context.delete(room)
    }

    // MARK: Spots and containers

    /// The room's top-level spots, in order.
    public func spots(in room: Room) -> [Spot] {
        (room.spots ?? []).filter { $0.parent == nil }.sorted(by: Self.byOrder)
    }

    /// The containers inside a spot, in order.
    public func containers(in spot: Spot) -> [Spot] {
        (spot.children ?? []).sorted(by: Self.byOrder)
    }

    /// Adds a spot to a room, or a container inside a spot (one level only, D3).
    @discardableResult
    public func addSpot(named name: String, in room: Room, inside parent: Spot? = nil) throws -> Spot {
        let name = try validated(name)
        if let parent, parent.isContainer { throw Failure.containerTooDeep }
        let siblings = parent.map(containers(in:)) ?? spots(in: room)
        let spot = Spot(name: name, order: (siblings.last?.order ?? -1) + 1)
        context.insert(spot)
        spot.room = room
        spot.parent = parent
        return spot
    }

    public func rename(_ spot: Spot, to name: String) throws {
        spot.name = try validated(name)
    }

    public func reorder(_ spots: [Spot]) {
        for (index, spot) in spots.enumerated() where spot.order != index {
            spot.order = index
        }
    }

    /// Deletes a spot and the containers in it. Same rule as rooms for items.
    public func delete(_ spot: Spot) throws {
        guard allItems(in: spot).allSatisfy({ $0.deletedAt != nil }) else { throw Failure.hasItems }
        context.delete(spot)
    }

    // MARK: Helpers

    private func validated(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.emptyName }
        return trimmed
    }

    private func allItems(in spot: Spot) -> [Item] {
        (spot.items ?? []) + (spot.children ?? []).flatMap { $0.items ?? [] }
    }

    private static func byOrder(_ a: Spot, _ b: Spot) -> Bool {
        (a.order, a.createdAt) < (b.order, b.createdAt)
    }
}
