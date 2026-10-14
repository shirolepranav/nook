import Foundation
import SwiftData

/// What the widgets show (F10, 01 §12), read from the App Group store. Private and deleted
/// items never count (PRD §9), not even toward the total (D61).
public struct WidgetSnapshot: Sendable, Equatable {
    public struct Ending: Sendable, Equatable, Identifiable {
        public let id: UUID   // the item
        public let name: String
        public let end: Date
        public let colorKey: String
    }

    public struct RoomValue: Sendable, Equatable {
        public let name: String
        public let colorKey: String
        public let total: Decimal
    }

    /// Warranties ending in the next 30 days (H-01's rule), soonest first.
    public var ending: [Ending]
    /// Prices in the home currency only; nothing is converted (D41).
    public var total: Decimal
    public var itemCount: Int
    /// The rooms worth the most, for the medium Total value widget.
    public var topRooms: [RoomValue]

    public static let empty = WidgetSnapshot(ending: [], total: 0, itemCount: 0, topRooms: [])

    /// A sample for the widget gallery and placeholders, so nothing real shows there.
    public static let sample = WidgetSnapshot(
        ending: [Ending(id: UUID(), name: "Dishwasher", end: .now.addingTimeInterval(12 * 86_400), colorKey: "sky"),
                 Ending(id: UUID(), name: "Espresso machine", end: .now.addingTimeInterval(26 * 86_400), colorKey: "clay")],
        total: 12_480, itemCount: 124,
        topRooms: [RoomValue(name: "Kitchen", colorKey: "clay", total: 4_210),
                   RoomValue(name: "Living room", colorKey: "sky", total: 3_640),
                   RoomValue(name: "Bedroom", colorKey: "lavender", total: 2_980)])

    public init(ending: [Ending], total: Decimal, itemCount: Int, topRooms: [RoomValue]) {
        (self.ending, self.total, self.itemCount, self.topRooms) = (ending, total, itemCount, topRooms)
    }

    public static func read(from context: ModelContext, now: Date, currencyCode: String,
                            calendar: Calendar = .current) throws -> WidgetSnapshot {
        let items = try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil && !$0.isPrivate }))
        let ending = items.compactMap { item -> Ending? in
            guard let end = item.primaryWarranty?.endDate,
                  SearchFilter.status(of: end, now: now, calendar: calendar) == .ending else { return nil }
            return Ending(id: item.id, name: item.name, end: end, colorKey: item.room?.colorKey ?? "stone")
        }
        .sorted { $0.end < $1.end }
        var total: Decimal = 0
        var byRoom: [UUID: (Room, Decimal)] = [:]
        for item in items {
            guard let price = item.price, item.currencyCode.isEmpty || item.currencyCode == currencyCode else { continue }
            let value = price   // as Home's total (D41)
            total += value
            if let room = item.room { byRoom[room.id, default: (room, 0)].1 += value }
        }
        let topRooms = byRoom.values.sorted { $0.1 > $1.1 }.prefix(3)
            .map { RoomValue(name: $0.0.name, colorKey: $0.0.colorKey, total: $0.1) }
        return WidgetSnapshot(ending: ending, total: total, itemCount: items.count, topRooms: Array(topRooms))
    }
}
