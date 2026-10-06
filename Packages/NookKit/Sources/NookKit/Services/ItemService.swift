import Foundation
import SwiftData

/// An item's editable fields, held by the editor (I-02) until Save. Photos and receipts are
/// already on disk (D40); the draft holds their file names.
public struct ItemDraft: Equatable {
    public struct DraftPhoto: Equatable, Sendable {
        public var fileName: String
        public var width: Int
        public var height: Int

        public init(fileName: String, width: Int, height: Int) {
            (self.fileName, self.width, self.height) = (fileName, width, height)
        }
    }

    public struct DraftReceipt: Equatable, Sendable {
        public var fileName: String
        public var kind: Receipt.Kind

        public init(fileName: String, kind: Receipt.Kind) {
            (self.fileName, self.kind) = (fileName, kind)
        }
    }

    public var name = ""
    public var category = ""
    public var tags: [String] = []
    public var quantity = 1
    public var brand = ""
    public var model = ""
    public var serial = ""
    public var barcode = ""
    public var price: Decimal?
    public var currencyCode = ""
    public var purchaseDate: Date?
    public var store = ""
    public var notes = ""
    public var isPrivate = false
    /// In order; the first is the cover.
    public var photos: [DraftPhoto] = []
    public var receipts: [DraftReceipt] = []
    public var location: Location?

    public init(currencyCode: String = "", location: Location? = nil) {
        self.currencyCode = currencyCode
        self.location = location
    }

    public init(_ item: Item) {
        (name, category, tags, quantity, brand, model, serial, barcode) =
            (item.name, item.category, item.tags, item.quantity, item.brand, item.model, item.serial, item.barcode)
        (price, currencyCode, purchaseDate, store, notes, isPrivate) =
            (item.price, item.currencyCode, item.purchaseDate, item.store, item.notes, item.isPrivate)
        photos = item.orderedPhotos.map { DraftPhoto(fileName: $0.fileName, width: $0.width, height: $0.height) }
        receipts = (item.receipts ?? []).map { DraftReceipt(fileName: $0.fileName, kind: $0.kind) }
        location = Location(of: item)
    }
}

extension Item {
    /// Photos in the user's order; the first is the cover.
    public var orderedPhotos: [Photo] {
        (photos ?? []).sorted { $0.order < $1.order }
    }

    public var cover: Photo? { orderedPhotos.first }
}

/// Items (F2) and Recently Deleted (D14). Every item change goes through here; location
/// changes go on to `LocationService` (D38).
@MainActor
public struct ItemService {
    public enum Failure: Error, Equatable {
        case emptyName
        case tooManyPhotos
    }

    /// D7.
    public static let maxPhotos = 10
    /// D14.
    public static let keepDeletedDays = 30

    let context: ModelContext
    let blobs: BlobStore
    let now: () -> Date

    public init(context: ModelContext, blobs: BlobStore = .shared, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.blobs = blobs
        self.now = now
    }

    // MARK: Create and edit

    /// Only the name is required (F2).
    @discardableResult
    public func create(_ draft: ItemDraft) throws -> Item {
        // P11: check EntitlementStore.canAddItems here, not in a view (D9).
        let item = Item(name: "")
        try apply(draft, to: item)
        context.insert(item)
        item.createdAt = now()
        item.lastConfirmedAt = now()
        try write(draft, into: item)
        return item
    }

    public func update(_ item: Item, from draft: ItemDraft) throws {
        try apply(draft, to: item)
        try write(draft, into: item)
    }

    /// A copy with the same fields, place and copies of its photos and receipts; not its
    /// history or loans.
    @discardableResult
    public func duplicate(_ item: Item) throws -> Item {
        var draft = ItemDraft(item)
        draft.photos = try draft.photos.map {
            .init(fileName: try blobs.copy($0.fileName, in: .photos), width: $0.width, height: $0.height)
        }
        draft.receipts = try draft.receipts.map {
            .init(fileName: try blobs.copy($0.fileName, in: .receipts), kind: $0.kind)
        }
        return try create(draft)
    }

    // MARK: Quick actions (I-01, I-03, I-08)

    public func setCover(_ photo: Photo) {
        guard let item = photo.item else { return }
        let others = item.orderedPhotos.filter { $0.id != photo.id }
        for (index, each) in ([photo] + others).enumerated() where each.order != index { each.order = index }
    }

    /// Removes one photo; Undo puts it back (D35). Its file stays until the sweep (D40).
    public func removePhoto(_ photo: Photo) {
        guard let item = photo.item else { return }
        let saved = (photo.fileName, photo.width, photo.height, photo.order)
        context.deleteWithUndo(photo) { context in
            let restored = Photo(fileName: saved.0)
            (restored.width, restored.height, restored.order) = (saved.1, saved.2, saved.3)
            context.insert(restored)
            restored.item = item
        }
    }

    public func setPrivate(_ items: [Item], _ isPrivate: Bool) {
        for item in items where item.isPrivate != isPrivate { item.isPrivate = isPrivate }
    }

    public func addTag(_ tag: String, to items: [Item]) {
        let tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        for item in items where !item.tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
            item.tags.append(tag)
        }
    }

    // MARK: Delete and Recently Deleted (D14)

    /// Sends items to Recently Deleted. A plain property change, so the window's Undo works.
    public func delete(_ items: [Item]) {
        for item in items where item.deletedAt == nil { item.deletedAt = now() }
    }

    public func restore(_ items: [Item]) {
        for item in items { item.deletedAt = nil }
    }

    /// Whole days left before the purge, never below 0.
    public func daysLeft(_ item: Item) -> Int {
        guard let deletedAt = item.deletedAt else { return Self.keepDeletedDays }
        let days = Calendar.current.dateComponents([.day], from: deletedAt, to: now()).day ?? 0
        return max(0, Self.keepDeletedDays - days)
    }

    /// Final: the rows and their files are gone (D40). Callers confirm first.
    public func deleteNow(_ items: [Item]) {
        for item in items {
            blobs.remove((item.photos ?? []).map(\.fileName), in: .photos)
            blobs.remove((item.receipts ?? []).map(\.fileName), in: .receipts)
            context.delete(item)
        }
    }

    /// Deletes for good what has been in Recently Deleted for 30 days. Runs at launch.
    public func purgeExpired() throws {
        let cutoff = now().addingTimeInterval(-Double(Self.keepDeletedDays) * 86_400)
        deleteNow(try deleted().filter { $0.deletedAt! <= cutoff })
    }

    /// The files rows still point at, for `BlobStore.sweepOrphans`.
    public func referencedFiles() throws -> (photos: Set<String>, receipts: Set<String>) {
        let photos = try context.fetch(FetchDescriptor<Photo>()).map(\.fileName)
        let receipts = try context.fetch(FetchDescriptor<Receipt>()).map(\.fileName)
        return (Set(photos), Set(receipts))
    }

    // MARK: Queries (deleted items are left out)

    /// Items placed straight in the room, not in one of its spots.
    public func looseItems(in room: Room) -> [Item] {
        live(room.items ?? []).filter { $0.spot == nil }
    }

    public func items(in spot: Spot) -> [Item] {
        live(spot.items ?? [])
    }

    /// Everything in a room, its spots and containers included.
    public func allItems(in room: Room) -> [Item] {
        live(room.items ?? [])
    }

    public func recentlyAdded(limit: Int) throws -> [Item] {
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil },
                                               sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    public func deleted() throws -> [Item] {
        try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt != nil },
                                                sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]))
    }

    /// Names, categories and stores the user has typed before, for autocomplete (PRD §5).
    public func pastValues(_ field: KeyPath<Item, String>) throws -> [String] {
        var seen = Set<String>()
        return try context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            .map { $0[keyPath: field] }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    // MARK: Private

    /// Unlinks first, so the item's list is right before the next save.
    private func remove(_ photo: Photo) {
        photo.item = nil
        context.delete(photo)
    }

    private func remove(_ receipt: Receipt) {
        receipt.item = nil
        context.delete(receipt)
    }

    private func live(_ items: [Item]) -> [Item] {
        items.filter { $0.deletedAt == nil }.sorted { $0.createdAt < $1.createdAt }
    }

    private func apply(_ draft: ItemDraft, to item: Item) throws {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Failure.emptyName }
        guard draft.photos.count <= Self.maxPhotos else { throw Failure.tooManyPhotos }
        let trim = { (text: String) in text.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Assign only what changed, so Undo and later sync see real edits.
        func set<Value: Equatable>(_ path: ReferenceWritableKeyPath<Item, Value>, _ value: Value) {
            if item[keyPath: path] != value { item[keyPath: path] = value }
        }
        set(\.name, name)
        set(\.category, trim(draft.category))
        set(\.tags, draft.tags.map(trim).filter { !$0.isEmpty })
        set(\.quantity, max(1, draft.quantity))
        set(\.brand, trim(draft.brand))
        set(\.model, trim(draft.model))
        set(\.serial, trim(draft.serial))
        set(\.barcode, trim(draft.barcode))
        set(\.price, draft.price)
        set(\.currencyCode, draft.currencyCode)
        set(\.purchaseDate, draft.purchaseDate)
        set(\.store, trim(draft.store))
        set(\.notes, draft.notes.trimmingCharacters(in: .whitespacesAndNewlines))
        set(\.isPrivate, draft.isPrivate)
    }

    /// Photos, receipts and place: rows follow the draft. Removed rows keep their files for
    /// the sweep (D40).
    /// ponytail: Undo of an edit restores fields but not photos removed in it (D35); the
    /// editor's Cancel is the way back. Snapshot them if ⌘Z after Save needs it.
    private func write(_ draft: ItemDraft, into item: Item) throws {
        let existing = Dictionary((item.photos ?? []).map { ($0.fileName, $0) }, uniquingKeysWith: { a, _ in a })
        let kept = Set(draft.photos.map(\.fileName))
        for photo in item.photos ?? [] where !kept.contains(photo.fileName) { remove(photo) }
        for (index, draftPhoto) in draft.photos.enumerated() {
            if let photo = existing[draftPhoto.fileName] {
                if photo.order != index { photo.order = index }
            } else {
                let photo = Photo(fileName: draftPhoto.fileName)
                (photo.width, photo.height, photo.order) = (draftPhoto.width, draftPhoto.height, index)
                context.insert(photo)
                photo.item = item
            }
        }
        let receiptNames = Set((item.receipts ?? []).map(\.fileName))
        let keptReceipts = Set(draft.receipts.map(\.fileName))
        for receipt in item.receipts ?? [] where !keptReceipts.contains(receipt.fileName) { remove(receipt) }
        for draftReceipt in draft.receipts where !receiptNames.contains(draftReceipt.fileName) {
            let receipt = Receipt(fileName: draftReceipt.fileName, kind: draftReceipt.kind)
            context.insert(receipt)
            receipt.item = item
        }
        LocationService(context: context, now: now).move([item], to: draft.location)
    }
}
