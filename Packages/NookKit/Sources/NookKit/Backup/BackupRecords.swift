import Foundation
import SwiftData

// `data.json` in a `.nookbackup` (D12, 04 §5): every row of every model, relationships as
// ids. Fields mirror `NookSchemaV2` one to one, and `BackupTests` fails if a model gains a
// field these don't carry. A field added in a later schema must be optional here, so older
// backups still decode.

/// A model a backup can rebuild.
protocol BackupModel: PersistentModel {
    var id: UUID { get }
}

/// A row in `data.json`.
protocol BackupRecord: Codable {
    associatedtype Model: BackupModel
    var id: UUID { get }
    init(_ model: Model)
    func makeModel() -> Model
    /// Copies the fields, not the relationships.
    func write(to model: Model)
    /// Sets the relationships, once every row exists.
    @MainActor func link(_ model: Model, _ rows: BackupRows)
}

extension Room: BackupModel {}
extension Spot: BackupModel {}
extension Item: BackupModel {}
extension Photo: BackupModel {}
extension Receipt: BackupModel {}
extension Warranty: BackupModel {}
extension LocationEvent: BackupModel {}
extension Loan: BackupModel {}
extension SavedSearch: BackupModel {}

/// Every row by id, the store's and the backup's, for linking.
@MainActor
final class BackupRows {
    var rooms: [UUID: Room] = [:]
    var spots: [UUID: Spot] = [:]
    var items: [UUID: Item] = [:]
}

struct BackupData: Codable {
    var rooms: [RoomRecord] = []
    var spots: [SpotRecord] = []
    var items: [ItemRecord] = []
    var photos: [PhotoRecord] = []
    var receipts: [ReceiptRecord] = []
    var warranties: [WarrantyRecord] = []
    var events: [EventRecord] = []
    var loans: [LoanRecord] = []
    var savedSearches: [SavedSearchRecord] = []
}

struct RoomRecord: BackupRecord {
    var id: UUID, name: String, symbol: String, colorKey: String, order: Int, createdAt: Date

    init(_ m: Room) {
        (id, name, symbol, colorKey, order, createdAt) = (m.id, m.name, m.symbol, m.colorKey, m.order, m.createdAt)
    }
    func makeModel() -> Room { let m = Room(name: name, symbol: symbol, colorKey: colorKey, order: order); m.id = id; return m }
    func write(to m: Room) { (m.name, m.symbol, m.colorKey, m.order, m.createdAt) = (name, symbol, colorKey, order, createdAt) }
    func link(_ m: Room, _ rows: BackupRows) {}
}

struct SpotRecord: BackupRecord {
    var id: UUID, name: String, qrID: String, packedAt: Date?, order: Int, createdAt: Date, kindRaw: String
    var roomID: UUID?, parentID: UUID?

    init(_ m: Spot) {
        (id, name, qrID, packedAt, order, createdAt, kindRaw) = (m.id, m.name, m.qrID, m.packedAt, m.order, m.createdAt, m.kindRaw)
        (roomID, parentID) = (m.room?.id, m.parent?.id)
    }
    func makeModel() -> Spot { let m = Spot(name: name, order: order); m.id = id; return m }
    func write(to m: Spot) {
        (m.name, m.qrID, m.packedAt, m.order, m.createdAt, m.kindRaw) = (name, qrID, packedAt, order, createdAt, kindRaw)
    }
    func link(_ m: Spot, _ rows: BackupRows) {
        m.room = roomID.flatMap { rows.rooms[$0] }
        m.parent = parentID.flatMap { rows.spots[$0] }
    }
}

struct ItemRecord: BackupRecord {
    var id: UUID, name: String, category: String, tags: [String], quantity: Int, brand: String, model: String
    var serial: String, barcode: String, price: Decimal?, currencyCode: String, purchaseDate: Date?, store: String
    var notes: String, isPrivate: Bool, condition: String, valueEstimateLow: Decimal?, valueEstimateHigh: Decimal?
    var createdAt: Date, lastConfirmedAt: Date, lastSeenAt: Date?, deletedAt: Date?
    var roomID: UUID?, spotID: UUID?

    init(_ m: Item) {
        (id, name, category, tags, quantity, brand, model) = (m.id, m.name, m.category, m.tags, m.quantity, m.brand, m.model)
        (serial, barcode, price, currencyCode, purchaseDate, store) = (m.serial, m.barcode, m.price, m.currencyCode, m.purchaseDate, m.store)
        (notes, isPrivate, condition, valueEstimateLow, valueEstimateHigh) = (m.notes, m.isPrivate, m.condition, m.valueEstimateLow, m.valueEstimateHigh)
        (createdAt, lastConfirmedAt, lastSeenAt, deletedAt) = (m.createdAt, m.lastConfirmedAt, m.lastSeenAt, m.deletedAt)
        (roomID, spotID) = (m.room?.id, m.spot?.id)
    }
    func makeModel() -> Item { let m = Item(name: name); m.id = id; return m }
    func write(to m: Item) {
        (m.name, m.category, m.tags, m.quantity, m.brand, m.model) = (name, category, tags, quantity, brand, model)
        (m.serial, m.barcode, m.price, m.currencyCode, m.purchaseDate, m.store) = (serial, barcode, price, currencyCode, purchaseDate, store)
        (m.notes, m.isPrivate, m.condition, m.valueEstimateLow, m.valueEstimateHigh) = (notes, isPrivate, condition, valueEstimateLow, valueEstimateHigh)
        (m.createdAt, m.lastConfirmedAt, m.lastSeenAt, m.deletedAt) = (createdAt, lastConfirmedAt, lastSeenAt, deletedAt)
    }
    /// A restore puts back the saved place as data, with no new history, so it doesn't go
    /// through `LocationService.move` (D56).
    func link(_ m: Item, _ rows: BackupRows) {
        m.room = roomID.flatMap { rows.rooms[$0] }
        m.spot = spotID.flatMap { rows.spots[$0] }
    }
}

struct PhotoRecord: BackupRecord {
    var id: UUID, fileName: String, width: Int, height: Int
    var boxX: Double?, boxY: Double?, boxW: Double?, boxH: Double?, order: Int
    var itemID: UUID?, spotID: UUID?

    init(_ m: Photo) {
        (id, fileName, width, height, order) = (m.id, m.fileName, m.width, m.height, m.order)
        (boxX, boxY, boxW, boxH) = (m.boxX, m.boxY, m.boxW, m.boxH)
        (itemID, spotID) = (m.item?.id, m.spot?.id)
    }
    func makeModel() -> Photo { let m = Photo(fileName: fileName); m.id = id; return m }
    func write(to m: Photo) {
        (m.fileName, m.width, m.height, m.order) = (fileName, width, height, order)
        (m.boxX, m.boxY, m.boxW, m.boxH) = (boxX, boxY, boxW, boxH)
    }
    func link(_ m: Photo, _ rows: BackupRows) {
        m.item = itemID.flatMap { rows.items[$0] }
        m.spot = spotID.flatMap { rows.spots[$0] }
    }
}

struct ReceiptRecord: BackupRecord {
    var id: UUID, fileName: String, kindRaw: String, extractedText: String, itemID: UUID?

    init(_ m: Receipt) { (id, fileName, kindRaw, extractedText, itemID) = (m.id, m.fileName, m.kindRaw, m.extractedText, m.item?.id) }
    func makeModel() -> Receipt { let m = Receipt(fileName: fileName, kind: .image); m.id = id; return m }
    func write(to m: Receipt) { (m.fileName, m.kindRaw, m.extractedText) = (fileName, kindRaw, extractedText) }
    func link(_ m: Receipt, _ rows: BackupRows) { m.item = itemID.flatMap { rows.items[$0] } }
}

struct WarrantyRecord: BackupRecord {
    var id: UUID, kindRaw: String, provider: String, startDate: Date?, endDate: Date?, lengthMonths: Int?
    var policyNumber: String, cost: Decimal?, notes: String, reminderOffsetsDays: [Int], snoozedUntil: Date?
    var itemID: UUID?

    init(_ m: Warranty) {
        (id, kindRaw, provider, startDate, endDate, lengthMonths) = (m.id, m.kindRaw, m.provider, m.startDate, m.endDate, m.lengthMonths)
        (policyNumber, cost, notes, reminderOffsetsDays, snoozedUntil) = (m.policyNumber, m.cost, m.notes, m.reminderOffsetsDays, m.snoozedUntil)
        itemID = m.item?.id
    }
    func makeModel() -> Warranty { let m = Warranty(kind: .manufacturer); m.id = id; return m }
    func write(to m: Warranty) {
        (m.kindRaw, m.provider, m.startDate, m.endDate, m.lengthMonths) = (kindRaw, provider, startDate, endDate, lengthMonths)
        (m.policyNumber, m.cost, m.notes, m.reminderOffsetsDays, m.snoozedUntil) = (policyNumber, cost, notes, reminderOffsetsDays, snoozedUntil)
    }
    func link(_ m: Warranty, _ rows: BackupRows) { m.item = itemID.flatMap { rows.items[$0] } }
}

struct EventRecord: BackupRecord {
    var id: UUID, fromPath: String, toPath: String, fromSpotID: UUID?, toSpotID: UUID?, toRoomID: UUID?
    var date: Date, sourceRaw: String, itemID: UUID?

    init(_ m: LocationEvent) {
        (id, fromPath, toPath, fromSpotID, toSpotID, toRoomID) = (m.id, m.fromPath, m.toPath, m.fromSpotID, m.toSpotID, m.toRoomID)
        (date, sourceRaw, itemID) = (m.date, m.sourceRaw, m.item?.id)
    }
    func makeModel() -> LocationEvent { let m = LocationEvent(fromPath: fromPath, toPath: toPath, source: .manual); m.id = id; return m }
    func write(to m: LocationEvent) {
        (m.fromPath, m.toPath, m.fromSpotID, m.toSpotID, m.toRoomID) = (fromPath, toPath, fromSpotID, toSpotID, toRoomID)
        (m.date, m.sourceRaw) = (date, sourceRaw)
    }
    func link(_ m: LocationEvent, _ rows: BackupRows) { m.item = itemID.flatMap { rows.items[$0] } }
}

struct LoanRecord: BackupRecord {
    var id: UUID, personName: String, contactID: String?, lentAt: Date, dueAt: Date?, returnedAt: Date?
    var remind: Bool, snoozedUntil: Date?, itemID: UUID?

    init(_ m: Loan) {
        (id, personName, contactID, lentAt, dueAt, returnedAt) = (m.id, m.personName, m.contactID, m.lentAt, m.dueAt, m.returnedAt)
        (remind, snoozedUntil, itemID) = (m.remind, m.snoozedUntil, m.item?.id)
    }
    func makeModel() -> Loan { let m = Loan(personName: personName); m.id = id; return m }
    func write(to m: Loan) {
        (m.personName, m.contactID, m.lentAt, m.dueAt, m.returnedAt) = (personName, contactID, lentAt, dueAt, returnedAt)
        (m.remind, m.snoozedUntil) = (remind, snoozedUntil)
    }
    func link(_ m: Loan, _ rows: BackupRows) { m.item = itemID.flatMap { rows.items[$0] } }
}

struct SavedSearchRecord: BackupRecord {
    var id: UUID, name: String, query: String, filterData: Data?, order: Int, createdAt: Date

    init(_ m: SavedSearch) {
        (id, name, query, filterData, order, createdAt) = (m.id, m.name, m.query, m.filterData, m.order, m.createdAt)
    }
    func makeModel() -> SavedSearch { let m = SavedSearch(name: name, query: query, filter: SearchFilter(), order: order); m.id = id; return m }
    func write(to m: SavedSearch) { (m.name, m.query, m.filterData, m.order, m.createdAt) = (name, query, filterData, order, createdAt) }
    func link(_ m: SavedSearch, _ rows: BackupRows) {}
}
