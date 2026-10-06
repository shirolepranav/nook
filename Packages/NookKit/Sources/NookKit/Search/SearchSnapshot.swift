import Foundation
import SwiftData

/// Reads the store into value snapshots for `SearchIndex` (04 §6, D46). Not tied to an actor:
/// the app calls it on a background `ModelContext`, so building the index never blocks the
/// main thread. Deleted items are left out.
public enum SearchSnapshot {
    public static func docs(in context: ModelContext) -> [SearchDoc] {
        let items = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        let rooms = (try? context.fetch(FetchDescriptor<Room>())) ?? []
        let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
        // One fetch per kind of record, grouped by item, instead of faulting each item's lists.
        var receipts: [UUID: [String]] = [:]
        for receipt in (try? context.fetch(FetchDescriptor<Receipt>())) ?? [] {
            if let id = receipt.item?.id, !receipt.extractedText.isEmpty { receipts[id, default: []].append(receipt.extractedText) }
        }
        var lent = Set<UUID>()
        for loan in (try? context.fetch(FetchDescriptor<Loan>(predicate: #Predicate { $0.returnedAt == nil }))) ?? [] {
            if let id = loan.item?.id { lent.insert(id) }
        }
        var warrantyEnds: [UUID: Date] = [:]
        for warranty in (try? context.fetch(FetchDescriptor<Warranty>())) ?? [] {
            guard let id = warranty.item?.id, let end = warranty.endDate else { continue }
            warrantyEnds[id] = max(end, warrantyEnds[id] ?? end)
        }

        let itemDocs = items.map { item in
            SearchDoc(id: item.id, kind: .item, name: item.name, tags: item.tags, category: item.category,
                      details: [item.brand, item.notes].filter { !$0.isEmpty },
                      codes: [item.model, item.serial, item.barcode].filter { !$0.isEmpty },
                      receiptText: receipts[item.id]?.joined(separator: "\n") ?? "",
                      path: Location(of: item)?.path ?? "", roomID: item.room?.id, isPrivate: item.isPrivate,
                      quantity: item.quantity, price: item.price, currencyCode: item.currencyCode,
                      lastConfirmedAt: item.lastConfirmedAt, isLent: lent.contains(item.id),
                      warrantyEnd: warrantyEnds[item.id])
        }
        let roomDocs = rooms.map { SearchDoc(id: $0.id, kind: .room, name: $0.name, roomID: $0.id) }
        let spotDocs = spots.compactMap { spot -> SearchDoc? in
            guard let room = spot.room else { return nil }
            let path = [room.name, spot.parent?.name].compactMap { $0 }.joined(separator: " → ")
            return SearchDoc(id: spot.id, kind: spot.isContainer ? .container : .spot, name: spot.name,
                             path: path, roomID: room.id)
        }
        return itemDocs + roomDocs + spotDocs
    }
}
