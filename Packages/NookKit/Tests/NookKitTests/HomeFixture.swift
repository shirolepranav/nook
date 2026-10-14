import Foundation
import SwiftData
@testable import NookKit

/// A small home with every kind of record, at fixed dates, for the report, CSV and backup
/// tests (P10). It includes the awkward cases: commas, quotes and line breaks in text, emoji
/// and right-to-left names, a second currency, a Private item, a deleted item, an item with
/// no room, and a container inside a spot.
@MainActor
final class HomeFixture {
    let container: ModelContainer
    let blobs: BlobStore
    static let now = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15 UTC
    var context: ModelContext { container.mainContext }

    init(blobs: BlobStore = temporaryBlobStore(), seeded: Bool = true) throws {
        container = try NookStore.makeContainer(inMemory: true)
        self.blobs = blobs
        if seeded { try seed() }
    }

    private func seed() throws {
        let rooms = RoomService(context: context)
        let items = ItemService(context: context, blobs: blobs, now: { Self.now })
        let day = 86_400.0
        let kitchen = try rooms.addRoom(named: "Kitchen")
        let counter = try rooms.addSpot(named: "Counter", in: kitchen)
        let bin = try rooms.addContainer(named: "Bread bin", in: kitchen, inside: counter)
        let garage = try rooms.addRoom(named: "Garage")
        let shelf = try rooms.addSpot(named: "Metal shelf", in: garage)

        let photo = try blobs.savePhoto(jpeg(width: 64, height: 48))
        let receiptFile = try blobs.saveReceipt(jpeg(width: 40, height: 80))

        var espresso = ItemDraft(currencyCode: "USD", location: Location(room: kitchen, spot: counter))
        (espresso.name, espresso.category, espresso.brand, espresso.model) = ("Espresso machine", "Appliances", "Breville", "BES870")
        (espresso.serial, espresso.price, espresso.store, espresso.tags) = ("SN-4471", 649, "Harbor Home Goods", ["Coffee", "Gift"])
        espresso.purchaseDate = Self.now.addingTimeInterval(-200 * day)
        espresso.photos = [.init(fileName: photo.fileName, width: photo.width, height: photo.height)]
        espresso.receipts = [.init(fileName: receiptFile, kind: .image, extractedText: "Harbor Home Goods 649.00")]
        espresso.warranty = .init(endDate: Self.now.addingTimeInterval(165 * day))
        espresso.condition = .likeNew
        let machine = try items.create(espresso)

        var mug = ItemDraft(currencyCode: "EUR", location: Location(room: kitchen, spot: bin))
        (mug.name, mug.price, mug.quantity) = ("Mug, \"Best Dad\"", 12.5, 2)
        mug.notes = "Chipped handle\nStill fine"
        try items.create(mug)

        var drill = ItemDraft(currencyCode: "USD", location: Location(room: garage, spot: shelf))
        (drill.name, drill.price, drill.serial) = ("Cordless drill", 159, "DCD771")
        let lent = try items.create(drill)
        _ = try items.lend(lent, to: "Jordan", lentAt: Self.now.addingTimeInterval(-24 * day),
                           dueAt: Self.now.addingTimeInterval(5 * day), remind: true)

        var ring = ItemDraft(currencyCode: "USD", location: Location(room: garage))
        (ring.name, ring.price, ring.isPrivate) = ("Grandma’s ring", 1_800, true)
        try items.create(ring)

        var guitar = ItemDraft(currencyCode: "USD")
        guitar.name = "🎸 גיטרה"
        try items.create(guitar)

        var gone = ItemDraft(currencyCode: "USD", location: Location(room: garage))
        (gone.name, gone.price) = ("Old fan", 30)
        items.delete([try items.create(gone)])

        let search = SavedSearch(name: "Coffee things", query: "coffee", filter: SearchFilter(), order: 0)
        context.insert(search)
        LocationService(context: context, now: { Self.now }).move([machine], to: Location(room: kitchen, spot: counter), source: .manual)
        try context.save()
    }
}
