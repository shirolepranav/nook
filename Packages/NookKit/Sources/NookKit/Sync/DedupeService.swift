import Foundation
import SwiftData

/// Merges rows that share an `id` (04 §4, D58). CloudKit sync can't enforce unique ids, so
/// the same row arrives twice when one backup is restored on two devices, or when two devices
/// both set up the same preset room in onboarding. The earliest copy stays; anything only a
/// later copy holds moves onto it first, so nothing is lost.
@MainActor
public struct DedupeService {
    let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    /// Leaves first, so a parent's duplicate holds only children unique to it by the time
    /// it's merged. Returns how many rows were removed.
    @discardableResult
    public func run() throws -> Int {
        var removed = 0
        removed += try dropCopies(Photo.self, id: \.id)
        removed += try dropCopies(Receipt.self, id: \.id)
        removed += try dropCopies(Warranty.self, id: \.id)
        removed += try dropCopies(LocationEvent.self, id: \.id)
        removed += try dropCopies(Loan.self, id: \.id)
        removed += try dropCopies(SavedSearch.self, id: \.id)
        removed += try merge(Item.self, id: \.id, order: { $0.createdAt < $1.createdAt }) { keep, extra in
            for photo in extra.photos ?? [] { photo.item = keep }
            for receipt in extra.receipts ?? [] { receipt.item = keep }
            for warranty in extra.warranties ?? [] { warranty.item = keep }
            for event in extra.events ?? [] { event.item = keep }
            for loan in extra.loans ?? [] { loan.item = keep }
        }
        removed += try merge(Spot.self, id: \.id, order: { $0.createdAt < $1.createdAt }) { keep, extra in
            for child in extra.children ?? [] { child.parent = keep }
            for item in extra.items ?? [] { item.spot = keep }
            if keep.photo == nil, let photo = extra.photo { photo.spot = keep }
        }
        removed += try merge(Room.self, id: \.id, order: { $0.createdAt < $1.createdAt }) { keep, extra in
            for spot in extra.spots ?? [] { spot.room = keep }
            for item in extra.items ?? [] { item.room = keep }
        }
        if removed > 0 { try context.save() }
        return removed
    }

    /// Records with no children of their own: later copies are simply dropped.
    private func dropCopies<T: PersistentModel>(_ type: T.Type, id: KeyPath<T, UUID>) throws -> Int {
        try merge(type, id: id, order: { _, _ in false }) { _, _ in }
    }

    private func merge<T: PersistentModel>(_ type: T.Type, id: KeyPath<T, UUID>, order: (T, T) -> Bool,
                                           moveChildren: (_ keep: T, _ extra: T) -> Void) throws -> Int {
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<T>()), by: { $0[keyPath: id] })
        var removed = 0
        for rows in groups.values where rows.count > 1 {
            let sorted = rows.sorted(by: order)
            for extra in sorted.dropFirst() {
                moveChildren(sorted[0], extra)
                context.delete(extra)
                removed += 1
            }
        }
        return removed
    }
}
