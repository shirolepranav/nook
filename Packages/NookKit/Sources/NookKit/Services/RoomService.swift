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

    /// Where the items of a deleted room or spot go (D28).
    public enum Rehoming {
        case move(to: Location)
        case recentlyDeleted
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

    /// Deletes a room and its spots. Items still in it need `rehoming` (D28), or it throws.
    /// One Undo brings the room back with its items in place.
    public func delete(_ room: Room, rehoming: Rehoming? = nil) throws {
        let liveItems = Set((room.items ?? []) + (room.spots ?? []).flatMap(allItems)).filter { $0.deletedAt == nil }
        let snapshot = RoomSnapshot(room)
        try rehome(Array(liveItems), rehoming)
        context.deleteWithUndo(room) { snapshot.restore(in: $0) }
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

    /// Moves a container onto the room (nil) or into one of the room's spots. It goes through
    /// `LocationService`, so the items inside get a history entry (P4).
    public func place(_ container: Spot, inside spot: Spot?) throws {
        guard container.isContainer, let room = container.room else { throw Failure.containerTooDeep }
        do {
            try LocationService(context: context).move(container, to: Location(room: room, spot: spot))
        } catch {
            throw Failure.containerTooDeep
        }
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
    public func delete(_ spot: Spot, rehoming: Rehoming? = nil) throws {
        let snapshot = SpotSnapshot(spot)
        try rehome(allItems(in: spot).filter { $0.deletedAt == nil }, rehoming)
        let room = spot.room, parent = spot.parent
        context.deleteWithUndo(spot) { snapshot.restore(room: room, parent: parent, in: $0) }
    }

    // MARK: Helpers

    /// Moves or soft-deletes items without undo steps of their own: the delete's snapshot
    /// undo puts them back, since SwiftData's would point them at the deleted room (D35).
    private func rehome(_ items: [Item], _ rehoming: Rehoming?) throws {
        guard !items.isEmpty else { return }
        guard let rehoming else { throw Failure.hasItems }
        let undo = context.undoManager
        undo?.disableUndoRegistration()
        defer { undo?.enableUndoRegistration() }
        switch rehoming {
        case .move(let location): LocationService(context: context).move(items, to: location)
        case .recentlyDeleted: ItemService(context: context).delete(items)
        }
    }

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

/// A deleted room as it was, for Undo (D35). Items outlive the delete (nullify), so they're
/// kept by reference and linked back.
@MainActor
private struct RoomSnapshot {
    let id: UUID, name: String, symbol: String, colorKey: String, order: Int, createdAt: Date
    let items: [Item]
    let liveItemIDs: Set<UUID>   // these were live; a rehoming to Recently Deleted is undone
    let spots: [SpotSnapshot]   // spots and containers on the floor; containers in a spot nest

    init(_ room: Room) {
        (id, name, symbol, colorKey, order, createdAt) =
            (room.id, room.name, room.symbol, room.colorKey, room.order, room.createdAt)
        items = room.items ?? []
        liveItemIDs = Set(items.filter { $0.deletedAt == nil }.map(\.id))
        spots = (room.spots ?? []).filter { $0.parent == nil }.map(SpotSnapshot.init)
    }

    func restore(in context: ModelContext) {
        let room = Room(name: name, symbol: symbol, colorKey: colorKey, order: order)
        (room.id, room.createdAt) = (id, createdAt)
        context.insert(room)
        for item in items {
            item.room = room
            if liveItemIDs.contains(item.id) { item.deletedAt = nil }
        }
        for spot in spots { spot.restore(room: room, parent: nil, in: context) }
    }
}

/// A deleted spot or container and the containers in it, for Undo (D35).
/// The spot photo's file stays on disk until the sweep (D40), so Undo brings it back too.
@MainActor
private struct SpotSnapshot {
    let id: UUID, name: String, qrID: String, packedAt: Date?, order: Int, createdAt: Date
    let kind: Spot.Kind
    let items: [Item]
    let liveItemIDs: Set<UUID>
    let photo: (fileName: String, width: Int, height: Int)?
    let children: [SpotSnapshot]

    init(_ spot: Spot) {
        (id, name, qrID, packedAt, order, createdAt, kind) =
            (spot.id, spot.name, spot.qrID, spot.packedAt, spot.order, spot.createdAt, spot.kind)
        items = spot.items ?? []
        liveItemIDs = Set(items.filter { $0.deletedAt == nil }.map(\.id))
        photo = spot.photo.map { ($0.fileName, $0.width, $0.height) }
        children = (spot.children ?? []).map(SpotSnapshot.init)
    }

    func restore(room: Room?, parent: Spot?, in context: ModelContext) {
        let spot = Spot(name: name, kind: kind, order: order)
        (spot.id, spot.qrID, spot.packedAt, spot.createdAt) = (id, qrID, packedAt, createdAt)
        context.insert(spot)
        (spot.room, spot.parent) = (room, parent)
        for item in items {
            (item.room, item.spot) = (room, spot)
            if liveItemIDs.contains(item.id) { item.deletedAt = nil }
        }
        if let photo {
            let restored = Photo(fileName: photo.fileName)
            (restored.width, restored.height) = (photo.width, photo.height)
            context.insert(restored)
            spot.photo = restored
        }
        for child in children { child.restore(room: room, parent: spot, in: context) }
    }
}
