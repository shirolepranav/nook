import Foundation
import SwiftData
import Testing
@testable import NookKit

/// F10, PRD §9: widgets never count or name a Private item, and totals follow Home (D41):
/// the home currency only, deleted items left out.
@MainActor
@Test func widgetSnapshotLeavesPrivateItemsOut() throws {
    let home = try HomeFixture()
    let items = try home.context.fetch(FetchDescriptor<Item>())
    let ring = try #require(items.first { $0.name == "Grandma’s ring" })
    let warranty = Warranty(kind: .manufacturer)
    warranty.endDate = HomeFixture.now.addingTimeInterval(5 * 86_400)
    warranty.item = ring
    home.context.insert(warranty)
    let snapshot = try WidgetSnapshot.read(from: home.context, now: HomeFixture.now, currencyCode: "USD")

    // Espresso machine, mug, drill and guitar: not the ring (Private) or the fan (deleted).
    #expect(snapshot.itemCount == 4)
    #expect(snapshot.total == Decimal(808))   // 649 + 159; the mug is in euros (D41)
    #expect(!snapshot.ending.contains { $0.id == ring.id })
    #expect(snapshot.topRooms.map(\.name) == ["Kitchen", "Garage"])
}
