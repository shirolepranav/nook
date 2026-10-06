import Foundation
import SwiftData

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
    /// history survives deleting the spot.
    @Model
    public final class LocationEvent {
        public enum Source: String, Sendable { case manual, siri, ai, qr }

        public var id: UUID = UUID()
        public var fromPath: String = ""
        public var toPath: String = ""
        public var fromSpotID: UUID?
        public var toSpotID: UUID?
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
        public var remind: Bool = true

        public var item: Item?

        public init(personName: String) {
            self.personName = personName
        }
    }
}
