import AppIntents
import CoreSpotlight
import SwiftData
import NookKit

/// The store the intents read and write: the app's own, set at launch (04 §8). Intents run in
/// the app's process, so Siri and Shortcuts see exactly what Nook shows.
@MainActor
enum IntentStore {
    static var container: ModelContainer?
    /// Where opening intents (Add, Scan) send the app.
    static var router: AppRouter?

    static var context: ModelContext {
        get throws {
            guard let container else { throw IntentError.unavailable }
            return container.mainContext
        }
    }

    /// Search with Find's own matcher (typos, synonyms; 04 §6). Private items never come back
    /// to Siri, Shortcuts or Spotlight (PRD §9), so they're left out before matching.
    static func index(in context: ModelContext) -> SearchIndex {
        SearchIndex(docs: SearchSnapshot.docs(in: context).filter { !$0.isPrivate }, synonyms: SearchLibrary.synonyms)
    }
}

/// What a failed intent says. Plain words; never about AI (CLAUDE.md).
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable, notFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unavailable: "Nook couldn’t open your items. Open Nook and try again."
        case .notFound: "That isn’t in Nook anymore."
        }
    }
}

/// An item for Siri, Shortcuts and Spotlight (04 §8). Never a Private one.
struct ItemEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item", numericFormat: "\(placeholder: .int) items")
    static let defaultQuery = ItemQuery()

    let id: UUID
    @Property(title: "Name") var name: String
    @Property(title: "Place") var place: String
    let thumbnail: URL?

    init(_ item: Item) {
        id = item.id
        thumbnail = item.cover.map { BlobStore.shared.thumbnailURL(for: $0.fileName) }
        name = item.name
        place = Location(of: item)?.path ?? String(localized: "No room yet")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(place)", image: thumbnail.map { .init(url: $0) })
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = place
        attributes.thumbnailURL = thumbnail
        return attributes
    }
}

struct ItemQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ItemEntity] {
        try items(identifiers).map(ItemEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ItemEntity] {
        let context = try IntentStore.context
        let hits = IntentStore.index(in: context).search(string).filter { $0.kind == .item }
        return FindService(context: context).items(matching: Array(hits.prefix(20))).filter { !$0.isPrivate }.map(ItemEntity.init)
    }

    /// The most recently confirmed things, as Find's "Try asking" uses (D46).
    @MainActor
    func suggestedEntities() async throws -> [ItemEntity] {
        var fetch = FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil && !$0.isPrivate },
                                          sortBy: [SortDescriptor(\.lastConfirmedAt, order: .reverse)])
        fetch.fetchLimit = 20
        return try IntentStore.context.fetch(fetch).map(ItemEntity.init)
    }

    @MainActor
    func items(_ ids: [UUID]) throws -> [Item] {
        try IntentStore.context.fetch(FetchDescriptor<Item>(predicate: #Predicate {
            ids.contains($0.id) && $0.deletedAt == nil && !$0.isPrivate
        }))
    }
}

/// A room, spot or container: where things are, and where they can go (04 §8). One type for
/// all three, as Find treats them.
struct PlaceEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Place", numericFormat: "\(placeholder: .int) places")
    static let defaultQuery = PlaceQuery()

    let id: UUID
    @Property(title: "Name") var name: String
    /// "Bedroom → Wardrobe".
    @Property(title: "Path") var path: String
    let symbol: String

    init(_ location: Location) {
        id = location.spot?.id ?? location.room.id
        symbol = location.spot.map { $0.isContainer ? "shippingbox" : "square.stack.3d.up" } ?? location.room.symbol
        name = location.spot?.name ?? location.room.name
        path = location.path
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: path == name ? nil : "\(path)", image: .init(systemName: symbol))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = path
        return attributes
    }
}

struct PlaceQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PlaceEntity] {
        let context = try IntentStore.context
        return identifiers.compactMap { Self.location($0, in: context) }.map(PlaceEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PlaceEntity] {
        let context = try IntentStore.context
        let hits = IntentStore.index(in: context).search(string).filter { $0.kind != .item }
        return FindService(context: context).places(matching: Array(hits.prefix(20))).map(PlaceEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PlaceEntity] {
        try Self.all(in: IntentStore.context).map(PlaceEntity.init)
    }

    /// Every room, then its spots and containers, in Home's order.
    static func all(in context: ModelContext) throws -> [Location] {
        let rooms = try context.fetch(FetchDescriptor<Room>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)]))
        return rooms.flatMap { room in
            let spots = (room.spots ?? []).filter { $0.parent == nil }.sorted { $0.order < $1.order }
            return [Location(room: room)] + spots.flatMap { spot in
                [Location(room: room, spot: spot)]
                    + (spot.children ?? []).sorted { $0.order < $1.order }.map { Location(room: room, spot: $0) }
            }
        }
    }

    @MainActor
    static func location(_ id: UUID, in context: ModelContext) -> Location? {
        if let room = try? context.fetch(FetchDescriptor<Room>(predicate: #Predicate { $0.id == id })).first {
            return Location(room: room)
        }
        guard let spot = try? context.fetch(FetchDescriptor<Spot>(predicate: #Predicate { $0.id == id })).first,
              let room = spot.room ?? spot.parent?.room else { return nil }
        return Location(room: room, spot: spot)
    }
}
