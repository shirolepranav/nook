import Foundation
import SwiftData

/// The answer card for a search (F-03, PRD §6). Built only from records, so it can never
/// invent a location: with no record there's no answer. Lives in NookKit so the AI engine
/// (P9) can return the same type (D46).
public enum FindAnswer: Equatable, Sendable {
    /// "Office → Desk → Second drawer. You put them there on Aug 3."
    case location(item: UUID)
    /// "Jordan has your cordless drill. Since Sep 12 · due back Oct 1."
    case lent(item: UUID, person: String, since: Date, due: Date?)
    /// "Box 14, packed Jun 2."
    case packed(item: UUID, container: UUID, on: Date)
    /// "Yes, 2 packs." The item's own quantity.
    case quantity(item: UUID, count: Int)
    /// "22 things in the Garage.", grouped by spot. `place` is a room, spot or container.
    case contents(place: UUID, total: Int, groups: [ContentsGroup])

    public var itemID: UUID? {
        switch self {
        case .location(let id), .lent(let id, _, _, _), .packed(let id, _, _), .quantity(let id, _): id
        case .contents: nil
        }
    }
}

/// One spot's share of a "What's in…?" answer. Private items count but aren't named.
public struct ContentsGroup: Equatable, Sendable {
    /// The spot or container; nil for things placed straight in the room or spot.
    public let place: UUID?
    public let name: String?
    public let count: Int
    public let itemNames: [String]
}

/// Find's records side (04 §6): answers and saved searches. Searching itself is
/// `SearchIndex`; the names here (`items(matching:)`, `contents(of:)`) are the ones the AI
/// engine will call as tools in P9.
@MainActor
public struct FindService {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Answers (F-03)

    /// The answer for the best hit, or nil. Private items never answer (PRD §9), and a place
    /// at the top answers with what's in it.
    public func answer(_ question: FindQuestion, hits: [SearchHit]) -> FindAnswer? {
        let places = hits.filter { $0.kind != .item }
        if question.intent == .contents, let place = places.first { return contents(of: place.id) }
        guard let top = hits.first(where: { !$0.isPrivate }) else { return nil }
        if top.kind != .item { return contents(of: top.id) }
        guard let item = item(top.id) else { return nil }

        if let loan = activeLoan(of: item) {
            return .lent(item: item.id, person: loan.personName, since: loan.lentAt, due: loan.dueAt)
        }
        if question.intent == .who { return nil }   // asked who has it, and nobody does
        guard item.room != nil else { return nil }
        if let box = item.spot, box.isContainer, let packedAt = box.packedAt {
            return .packed(item: item.id, container: box.id, on: packedAt)
        }
        if question.intent == .quantity { return .quantity(item: item.id, count: item.quantity) }
        return .location(item: item.id)
    }

    /// Items found for hits, in hit order.
    public func items(matching hits: [SearchHit]) -> [Item] {
        let ids = hits.filter { $0.kind == .item }.map(\.id)
        let found = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        let byID = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }.filter { $0.deletedAt == nil }
    }

    /// Rooms, spots and containers found for hits, in hit order.
    public func places(matching hits: [SearchHit]) -> [Location] {
        hits.compactMap { hit in
            switch hit.kind {
            case .item: nil
            case .room: room(hit.id).map { Location(room: $0) }
            case .spot, .container: spot(hit.id).flatMap { spot in spot.room.map { Location(room: $0, spot: spot) } }
            }
        }
    }

    /// What's in a room, spot or container, grouped by the spot or container each thing is in.
    public func contents(of placeID: UUID) -> FindAnswer? {
        let service = ItemService(context: context)
        let grouped: [(UUID?, String?, [Item])]
        if let room = room(placeID) {
            let spots = (room.spots ?? []).filter { $0.parent == nil }.sorted { $0.order < $1.order }
            grouped = [(nil, nil, service.looseItems(in: room))] + spots.map { spot in
                (spot.id, spot.name, service.items(in: spot) + (spot.children ?? []).flatMap(service.items(in:)))
            }
        } else if let spot = spot(placeID) {
            let boxes = (spot.children ?? []).sorted { $0.order < $1.order }
            grouped = [(nil, nil, service.items(in: spot))] + boxes.map { ($0.id, $0.name, service.items(in: $0)) }
        } else {
            return nil
        }
        let groups = grouped.filter { !$0.2.isEmpty }.map { place, name, items in
            ContentsGroup(place: place, name: name, count: items.count,
                          itemNames: items.filter { !$0.isPrivate }.map(\.name))
        }
        return .contents(place: placeID, total: groups.map(\.count).reduce(0, +), groups: groups)
    }

    public func activeLoan(of item: Item) -> Loan? {
        (item.loans ?? []).filter { $0.returnedAt == nil }.max { $0.lentAt < $1.lentAt }
    }

    // MARK: Saved searches (F-06)

    public func savedSearches() -> [SavedSearch] {
        (try? context.fetch(FetchDescriptor<SavedSearch>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)]))) ?? []
    }

    @discardableResult
    public func save(name: String, query: String, filter: SearchFilter) -> SavedSearch {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let order = (savedSearches().map(\.order).max() ?? -1) + 1
        let saved = SavedSearch(name: name.isEmpty ? query : name, query: query, filter: filter, order: order)
        context.insert(saved)
        return saved
    }

    public func rename(_ saved: SavedSearch, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { saved.name = name }
    }

    /// Takes the search off Find; the items it found are untouched.
    public func delete(_ saved: SavedSearch) {
        context.delete(saved)
    }

    /// `List.onMove` order.
    public func move(_ saved: [SavedSearch], from source: IndexSet, to destination: Int) {
        var ordered = saved.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        ordered.insert(contentsOf: source.map { saved[$0] }, at: destination - source.count { $0 < destination })
        for (index, each) in ordered.enumerated() where each.order != index { each.order = index }
    }

    // MARK: Private

    private func item(_ id: UUID) -> Item? {
        (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })))?.first
    }

    private func room(_ id: UUID) -> Room? {
        (try? context.fetch(FetchDescriptor<Room>(predicate: #Predicate { $0.id == id })))?.first
    }

    private func spot(_ id: UUID) -> Spot? {
        (try? context.fetch(FetchDescriptor<Spot>(predicate: #Predicate { $0.id == id })))?.first
    }
}
