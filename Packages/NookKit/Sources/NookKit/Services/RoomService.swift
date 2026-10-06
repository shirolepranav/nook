import Foundation
import SwiftData

/// Rooms, spots and containers (F1). Every change to them goes through here, so the rules
/// hold everywhere: names aren't blank, order stays dense, a container sits in a room or a
/// spot but never in another container (D3, D34), and a room with items can't be deleted
/// until they're rehomed (D28, P3).
/// Undo comes from the context's `UndoManager`, which the app ties to the window (04 §9).
@MainActor
public struct RoomService {
    public enum Failure: Error, Equatable {
        case emptyName
        /// D3, D34: a container can't go inside another container, and a spot can't go inside
        /// anything.
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

    /// The room's spots, in order.
    public func spots(in room: Room) -> [Spot] {
        (room.spots ?? []).filter { $0.kind == .spot }.sorted(by: Self.byOrder)
    }

    /// The containers sitting on the room itself, not in a spot (D34).
    public func looseContainers(in room: Room) -> [Spot] {
        (room.spots ?? []).filter { $0.isContainer && $0.parent == nil }.sorted(by: Self.byOrder)
    }

    /// The containers inside a spot, in order.
    public func containers(in spot: Spot) -> [Spot] {
        (spot.children ?? []).sorted(by: Self.byOrder)
    }

    @discardableResult
    public func addSpot(named name: String, in room: Room) throws -> Spot {
        let name = try validated(name)
        let spot = Spot(name: name, kind: .spot, order: (spots(in: room).last?.order ?? -1) + 1)
        context.insert(spot)
        spot.room = room
        return spot
    }

    /// Adds a container to a room, or inside one of its spots (never inside a container, D34).
    @discardableResult
    public func addContainer(named name: String, in room: Room, inside spot: Spot? = nil) throws -> Spot {
        let name = try validated(name)
        if let spot, spot.isContainer || spot.room?.id != room.id { throw Failure.containerTooDeep }
        let siblings = spot.map(containers(in:)) ?? looseContainers(in: room)
        let container = Spot(name: name, kind: .container, order: (siblings.last?.order ?? -1) + 1)
        context.insert(container)
        container.room = room
        container.parent = spot
        return container
    }

    public func rename(_ spot: Spot, to name: String) throws {
        spot.name = try validated(name)
    }

    /// Moves a container onto the room (nil) or into one of the room's spots.
    public func place(_ container: Spot, inside spot: Spot?) throws {
        guard container.isContainer else { throw Failure.containerTooDeep }
        if let spot, spot.isContainer || spot.room?.id != container.room?.id { throw Failure.containerTooDeep }
        guard container.parent?.id != spot?.id else { return }
        let siblings = spot.map(containers(in:)) ?? container.room.map(looseContainers(in:)) ?? []
        container.parent = spot
        container.order = (siblings.last?.order ?? -1) + 1
    }

    /// Turns a spot into a container (it must hold no containers) or a container into a spot
    /// (it comes out onto the room).
    public func setKind(of spot: Spot, to kind: Spot.Kind) throws {
        guard spot.kind != kind else { return }
        if kind == .container, !(spot.children ?? []).isEmpty { throw Failure.containerTooDeep }
        let siblings = spot.room.map { kind == .spot ? spots(in: $0) : looseContainers(in: $0) } ?? []
        spot.parent = nil
        spot.kind = kind
        spot.order = (siblings.last?.order ?? -1) + 1   // joins the end of its new list
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
