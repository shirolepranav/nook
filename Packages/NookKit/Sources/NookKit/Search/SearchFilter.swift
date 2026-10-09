import Foundation

/// F-05 filters. Codable, so a saved search (F-06) keeps them. They apply to items only.
public struct SearchFilter: Codable, Hashable, Sendable {
    public enum WarrantyStatus: String, Codable, Sendable, CaseIterable {
        case any, active, ending, expired
    }

    /// "Last seen" is `lastConfirmedAt`: set on add, move and "Found it here" (D46).
    public enum LastSeen: String, Codable, Sendable, CaseIterable {
        case any, overOneYear, overTwoYears
    }

    /// R-04's "Ending in 30 days".
    public static let endingDays = 30

    public var roomIDs: Set<UUID> = []
    public var category: String?
    public var tags: Set<String> = []
    /// In the home currency; other currencies never match a value range (D41, D46).
    public var minValue: Decimal?
    public var maxValue: Decimal?
    public var warranty: WarrantyStatus = .any
    public var lentOnly = false
    public var lastSeen: LastSeen = .any

    public init() {}

    public var isEmpty: Bool { self == SearchFilter() }

    /// How many filters are on, for the chips and the button badge.
    public var count: Int {
        [!roomIDs.isEmpty, category != nil, !tags.isEmpty, minValue != nil || maxValue != nil,
         warranty != .any, lentOnly, lastSeen != .any].filter { $0 }.count
    }

    public func matches(_ doc: SearchDoc, homeCurrency: String, now: Date,
                        calendar: Calendar = .current) -> Bool {
        guard doc.kind == .item else { return false }
        if !roomIDs.isEmpty, doc.roomID.map(roomIDs.contains) != true { return false }
        if let category, doc.category.localizedCaseInsensitiveCompare(category) != .orderedSame { return false }
        if !tags.isEmpty {
            let own = Set(doc.tags.map(SearchText.fold))
            if !tags.allSatisfy({ own.contains(SearchText.fold($0)) }) { return false }
        }
        if minValue != nil || maxValue != nil {
            guard let price = doc.price, doc.currencyCode.isEmpty || doc.currencyCode == homeCurrency,
                  price >= (minValue ?? price), price <= (maxValue ?? price) else { return false }
        }
        if lentOnly, !doc.isLent { return false }
        switch warranty {
        case .any: break
        case .active, .ending, .expired:
            guard let end = doc.warrantyEnd, Self.status(of: end, now: now, calendar: calendar) == warranty else { return false }
        }
        switch lastSeen {
        case .any: break
        case .overOneYear, .overTwoYears:
            let years = lastSeen == .overOneYear ? -1 : -2
            guard let cutoff = calendar.date(byAdding: .year, value: years, to: now),
                  doc.lastConfirmedAt < cutoff else { return false }
        }
        return true
    }

    /// Active, ending within 30 days, or expired (R-04's groups). One rule for R-04, Home,
    /// I-01 and Find.
    public static func status(of end: Date, now: Date, calendar: Calendar = .current) -> WarrantyStatus {
        if end < now { return .expired }
        let soon = calendar.date(byAdding: .day, value: Self.endingDays, to: now) ?? now
        return end <= soon ? .ending : .active
    }
}
