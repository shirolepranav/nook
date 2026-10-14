import Foundation
import SwiftData
import Testing
@testable import NookKit

/// F10, PRD §9: widgets never count or name a Private item, and totals follow Home (D41).
@MainActor
@Test func widgetSnapshotLeavesPrivateItemsOut() throws {
    let container = PreviewStore.seeded(.lived)
    let context = container.mainContext
    let items = try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil }))
    let ring = try #require(items.first { $0.name == "Grandma’s ring" })
    let warranty = Warranty(kind: .manufacturer)
    warranty.endDate = Date.now.addingTimeInterval(5 * 86_400)
    warranty.item = ring
    context.insert(warranty)
    let currency = ring.currencyCode
    let snapshot = try WidgetSnapshot.read(from: context, now: .now, currencyCode: currency)

    let visible = items.filter { !$0.isPrivate }
    #expect(snapshot.itemCount == visible.count)
    #expect(snapshot.total == visible.compactMap(\.price).reduce(0, +))
    #expect(!snapshot.ending.contains { $0.id == ring.id })
    #expect(snapshot.topRooms.count <= 3)
    #expect(snapshot.topRooms.map(\.total) == snapshot.topRooms.map(\.total).sorted(by: >))
}
