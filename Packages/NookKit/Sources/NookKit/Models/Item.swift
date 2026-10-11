import Foundation
import SwiftData

extension NookSchemaV2 {
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
        /// An `ItemCondition` raw value; empty when not set (PRD F2, D53).
        public var condition: String = ""
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

/// How worn an item is (PRD F2, C-03). Stored as its raw value in `Item.condition`.
public enum ItemCondition: String, CaseIterable, Identifiable, Sendable {
    case new, likeNew, good, fair, worn
    public var id: String { rawValue }
}

extension Item {
    public var itemCondition: ItemCondition? {
        get { ItemCondition(rawValue: condition) }
        set { condition = newValue?.rawValue ?? "" }
    }
}
