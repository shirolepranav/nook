import Foundation
import SwiftData

// Version 1 of the store, frozen as shipped through P7 (data-model-change skill). Never edit
// it: SwiftData reads stores made with it through these classes, then migrates them to V2.
// The live models are in Models/.


extension NookSchemaV1 {
    /// A room in the home (F1). Holds spots, and items placed straight in the room.
    @Model
    public final class Room {
        public var id: UUID = UUID()
        public var name: String = ""
        /// SF Symbol name.
        public var symbol: String = "square.grid.2x2"
        /// A `RoomColor` raw value (NookUI); NookKit stays UI-free.
        public var colorKey: String = "stone"
        /// Position on Home; relationships can't be ordered in CloudKit (D8).
        public var order: Int = 0
        public var createdAt: Date = Date.now

        // A room owns its spots; items survive a room's deletion and are rehomed or sent to
        // Recently Deleted by the caller first (D28, P3).
        @Relationship(deleteRule: .cascade, inverse: \Spot.room) public var spots: [Spot]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.room) public var items: [Item]? = []

        public init(name: String, symbol: String, colorKey: String, order: Int) {
            self.name = name
            self.symbol = symbol
            self.colorKey = colorKey
            self.order = order
        }
    }
}


extension NookSchemaV1 {
    /// A place in a room ("Top shelf") or a container ("Box 14"). Spots are top-level in a
    /// room; a container sits in the room or inside a spot, never inside another container
    /// (D3, D34). `RoomService` enforces it.
    @Model
    public final class Spot {
        public enum Kind: String, Sendable { case spot, container }

        public var id: UUID = UUID()
        public var name: String = ""
        /// Encoded in the container's QR label as `nook://spot/<qrID>` (D19, P10).
        public var qrID: String = UUID().uuidString
        /// "Packed on" for moving (H-03).
        public var packedAt: Date?
        public var order: Int = 0
        public var createdAt: Date = Date.now
        public var kindRaw: String = Kind.spot.rawValue

        public var room: Room?
        /// The spot a container sits in; nil for spots, and for containers on the room itself.
        public var parent: Spot?
        @Relationship(deleteRule: .cascade, inverse: \Spot.parent) public var children: [Spot]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.spot) public var items: [Item]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.spot) public var photo: Photo?

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .spot }
            set { kindRaw = newValue.rawValue }
        }

        public var isContainer: Bool { kind == .container }

        public init(name: String, kind: Kind = .spot, order: Int) {
            self.name = name
            self.kindRaw = kind.rawValue
            self.order = order
        }
    }
}


extension NookSchemaV1 {
    /// A named search pinned on Find (F-06): the words and the filters. A model rather than
    /// a preference, so saved searches sync with everything else in P11 (D46).
    @Model
    public final class SavedSearch {
        public var id: UUID = UUID()
        public var name: String = ""
        public var query: String = ""
        /// A JSON `SearchFilter`; nil when there are no filters.
        public var filterData: Data?
        /// Position on Find; relationships can't be ordered in CloudKit (D8).
        public var order: Int = 0
        public var createdAt: Date = Date.now

        public var filter: SearchFilter {
            get { filterData.flatMap { try? JSONDecoder().decode(SearchFilter.self, from: $0) } ?? SearchFilter() }
            set { filterData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
        }

        public init(name: String, query: String, filter: SearchFilter, order: Int) {
            self.name = name
            self.query = query
            self.order = order
            self.filter = filter
        }
    }
}


extension NookSchemaV1 {
    /// Something the user owns (F2). Location fields change only through
    /// `LocationService.move(items:to:source:)` (P4).
    @Model
    public final class Item {
        public var id: UUID = UUID()
        public var name: String = ""
        public var category: String = ""
        public var tags: [String] = []
        public var quantity: Int = 1
        public var brand: String = ""
        public var model: String = ""
        public var serial: String = ""
        public var barcode: String = ""
        public var price: Decimal?
        /// Each item keeps its own currency; totals never convert (D20).
        public var currencyCode: String = ""
        public var purchaseDate: Date?
        public var store: String = ""
        public var notes: String = ""
        public var isPrivate: Bool = false
        /// AI estimate range, labeled as an estimate (D16, P9).
        public var valueEstimateLow: Decimal?
        public var valueEstimateHigh: Decimal?
        public var createdAt: Date = Date.now
        public var lastConfirmedAt: Date = Date.now
        public var lastSeenAt: Date?
        /// Set when deleted; Recently Deleted keeps it 30 days (D14).
        public var deletedAt: Date?

        public var room: Room?
        public var spot: Spot?
        @Relationship(deleteRule: .cascade, inverse: \Photo.item) public var photos: [Photo]? = []
        @Relationship(deleteRule: .cascade, inverse: \Receipt.item) public var receipts: [Receipt]? = []
        @Relationship(deleteRule: .cascade, inverse: \Warranty.item) public var warranties: [Warranty]? = []
        @Relationship(deleteRule: .cascade, inverse: \LocationEvent.item) public var events: [LocationEvent]? = []
        @Relationship(deleteRule: .cascade, inverse: \Loan.item) public var loans: [Loan]? = []

        public init(name: String) {
            self.name = name
        }
    }
}


// The records an item owns (04 §4). Each is deleted with its item (cascade). Blobs live on
// disk in the App Group; only file names are stored (D7, 04 §5).

extension NookSchemaV1 {
    @Model
    public final class Photo {
        public var id: UUID = UUID()
        public var fileName: String = ""
        public var width: Int = 0
        public var height: Int = 0
        /// The item's box in a room-scan photo, normalized 0–1 (F3).
        public var boxX: Double?
        public var boxY: Double?
        public var boxW: Double?
        public var boxH: Double?
        public var order: Int = 0

        public var item: Item?
        public var spot: Spot?

        public init(fileName: String) {
            self.fileName = fileName
        }
    }

    @Model
    public final class Receipt {
        public enum Kind: String, Sendable { case image, pdf }

        public var id: UUID = UUID()
        public var fileName: String = ""
        public var kindRaw: String = Kind.image.rawValue
        /// Recognized text, included in search (F5).
        public var extractedText: String = ""

        public var item: Item?

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .image }
            set { kindRaw = newValue.rawValue }
        }

        public init(fileName: String, kind: Kind) {
            self.fileName = fileName
            self.kindRaw = kind.rawValue
        }
    }

    /// A warranty is its own record, so an item can have several (D21).
    @Model
    public final class Warranty {
        public enum Kind: String, Sendable { case manufacturer, extended, store }

        public var id: UUID = UUID()
        public var kindRaw: String = Kind.manufacturer.rawValue
        public var provider: String = ""
        public var startDate: Date?
        public var endDate: Date?
        public var lengthMonths: Int?
        public var policyNumber: String = ""
        public var cost: Decimal?
        public var notes: String = ""
        /// Reminders are derived from these, never stored (D13, D21).
        public var reminderOffsetsDays: [Int] = [30, 7]
        public var snoozedUntil: Date?

        public var item: Item?

        public var kind: Kind {
            get { Kind(rawValue: kindRaw) ?? .manufacturer }
            set { kindRaw = newValue.rawValue }
        }

        public init(kind: Kind) {
            self.kindRaw = kind.rawValue
        }
    }

    /// One move in an item's location history (F6, I-05). Paths are stored as text so
    /// history survives deleting the spot. `toRoomID` lets the Move picker offer a room-only
    /// place again (I-04 recents, D44).
    @Model
    public final class LocationEvent {
        /// `found` is "Found it here instead" (I-01, F-03), a correction rather than a move (D44).
        public enum Source: String, Sendable, Identifiable {
            case manual, found, siri, ai, qr
            public var id: String { rawValue }
        }

        public var id: UUID = UUID()
        public var fromPath: String = ""
        public var toPath: String = ""
        public var fromSpotID: UUID?
        public var toSpotID: UUID?
        public var toRoomID: UUID?
        public var date: Date = Date.now
        public var sourceRaw: String = Source.manual.rawValue

        public var item: Item?

        public var source: Source {
            get { Source(rawValue: sourceRaw) ?? .manual }
            set { sourceRaw = newValue.rawValue }
        }

        public init(fromPath: String, toPath: String, source: Source) {
            self.fromPath = fromPath
            self.toPath = toPath
            self.sourceRaw = source.rawValue
        }
    }

    /// Lending an item (F7).
    @Model
    public final class Loan {
        public var id: UUID = UUID()
        public var personName: String = ""
        public var contactID: String?
        public var lentAt: Date = Date.now
        public var dueAt: Date?
        public var returnedAt: Date?
        /// Reminds the morning it's due, so only with a due date (D50).
        public var remind: Bool = true
        /// Set by the loan reminder's Snooze (04 §7).
        public var snoozedUntil: Date?

        public var item: Item?

        public init(personName: String) {
            self.personName = personName
        }
    }
}

