import Foundation
import SwiftData

/// An amount in one currency. Totals never convert (D20).
public struct Money: Sendable, Hashable {
    public var amount: Decimal
    public var currencyCode: String

    public init(_ amount: Decimal, _ currencyCode: String) {
        (self.amount, self.currencyCode) = (amount, currencyCode)
    }

    /// One total per currency, the home currency first (D20, D41).
    static func totals(_ values: [Money], homeCurrency: String) -> [Money] {
        let sums = Dictionary(grouping: values, by: \.currencyCode)
            .map { Money($0.value.reduce(Decimal(0)) { $0 + $1.amount }, $0.key) }
        return sums.sorted { ($0.currencyCode == homeCurrency ? 0 : 1, $0.currencyCode) < ($1.currencyCode == homeCurrency ? 0 : 1, $1.currencyCode) }
    }
}

/// What goes into the insurance report (R-02) or an item's proof pack (D4).
public struct ReportOptions: Sendable, Hashable {
    public enum Scope: Sendable, Hashable {
        case home
        case rooms(Set<UUID>)
        case item(UUID)
    }

    public var scope: Scope = .home
    public var photos = true
    public var serials = true
    public var receipts = true

    public init(scope: Scope = .home, photos: Bool = true, serials: Bool = true, receipts: Bool = true) {
        (self.scope, self.photos, self.serials, self.receipts) = (scope, photos, serials, receipts)
    }
}

/// The report's data, read from the store once so pages render without touching SwiftData
/// (04 §10). Grouped by room in Home's order (F9); items with no room come last.
///
/// Private items are included: the report is the owner's own document for their insurer
/// (D56). Deleted items are not.
public struct ReportSnapshot: Sendable {
    public struct Line: Sendable, Identifiable {
        public let id: UUID
        public let name: String
        /// "DeWalt · DCD771".
        public let detail: String
        /// Where in the room: "Metal shelf → Box 14". Empty for the room itself.
        public let place: String
        public let serial: String
        public let quantity: Int
        public let value: Money?
        public let photoFile: String?
        public let receiptCount: Int
        public let purchaseDate: Date?
    }

    public struct Section: Sendable, Identifiable {
        /// The room's id; nil (and an empty name) for items with no room.
        public let id: UUID?
        public let name: String
        public let lines: [Line]
        public let totals: [Money]
    }

    public struct ReceiptFile: Sendable {
        public let itemName: String
        public let fileName: String
        public let isPDF: Bool
    }

    public let sections: [Section]
    public let totals: [Money]
    /// The receipt appendix, in report order (F9).
    public let receipts: [ReceiptFile]

    public var itemCount: Int { sections.reduce(0) { $0 + $1.lines.count } }

    /// D20: true when any value isn't in the home currency.
    public func isMixed(homeCurrency: String) -> Bool {
        totals.contains { $0.currencyCode != homeCurrency }
    }

    @MainActor
    public static func make(_ options: ReportOptions, context: ModelContext, homeCurrency: String) throws -> ReportSnapshot {
        var items = try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil }))
        switch options.scope {
        case .home: break
        case .rooms(let ids): items = items.filter { $0.room.map { ids.contains($0.id) } ?? false }
        case .item(let id): items = items.filter { $0.id == id }
        }
        let byRoom = Dictionary(grouping: items) { $0.room?.id }
        let rooms = try context.fetch(FetchDescriptor<Room>(sortBy: [SortDescriptor(\.order)]))
        let groups: [(UUID?, String)] = rooms.map { ($0.id, $0.name) } + [(nil, "")]   // the app names it "No room"

        var sections: [Section] = []
        var receipts: [ReceiptFile] = []
        for (roomID, roomName) in groups {
            guard let roomItems = byRoom[roomID], !roomItems.isEmpty else { continue }
            let lines = roomItems
                .map { line(for: $0, homeCurrency: homeCurrency) }
                .sorted { ($0.place, $0.name.localizedLowercase) < ($1.place, $1.name.localizedLowercase) }
            sections.append(Section(id: roomID, name: roomName, lines: lines,
                                    totals: Money.totals(lines.compactMap(\.value), homeCurrency: homeCurrency)))
            guard options.receipts else { continue }
            let byID = Dictionary(uniqueKeysWithValues: roomItems.map { ($0.id, $0) })
            for line in lines {
                for receipt in byID[line.id]?.receipts ?? [] where !receipt.fileName.isEmpty {
                    receipts.append(ReceiptFile(itemName: line.name, fileName: receipt.fileName, isPDF: receipt.kind == .pdf))
                }
            }
        }
        let values = sections.flatMap(\.lines).compactMap(\.value)
        return ReportSnapshot(sections: sections, totals: Money.totals(values, homeCurrency: homeCurrency), receipts: receipts)
    }

    @MainActor
    private static func line(for item: Item, homeCurrency: String) -> Line {
        let place = [item.spot?.parent?.name, item.spot?.name].compactMap { $0 }.joined(separator: " → ")
        let detail = [item.brand, item.model].filter { !$0.isEmpty }.joined(separator: " · ")
        return Line(id: item.id, name: item.name, detail: detail, place: place, serial: item.serial,
                    quantity: item.quantity,
                    value: item.price.map { Money($0, item.currencyCode.isEmpty ? homeCurrency : item.currencyCode) },
                    photoFile: item.cover?.fileName, receiptCount: item.receipts?.count ?? 0,
                    purchaseDate: item.purchaseDate)
    }
}
