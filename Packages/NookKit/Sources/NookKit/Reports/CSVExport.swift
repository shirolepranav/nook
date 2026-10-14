import Foundation

/// R-03: every field of every item, one row each (F9). RFC 4180 quoting, a UTF-8 byte order
/// mark and CRLF line ends, so Numbers, Excel and Google Sheets all open it. Dates are
/// ISO 8601 days and prices plain decimals, with each item's own currency in its own column
/// (D20). Column titles stay English, like the file format itself.
public enum CSVExport {
    public static let columns = [
        "Name", "Room", "Spot", "Container", "Category", "Tags", "Quantity", "Brand", "Model", "Serial",
        "Barcode", "Condition", "Price", "Currency", "Purchase date", "Store", "Warranty ends",
        "Warranty provider", "Lent to", "Due back", "Last confirmed", "Notes", "Private", "Added",
    ]

    @MainActor
    public static func csv(_ items: [Item], homeCurrency: String, timeZone: TimeZone = .current) -> String {
        let day = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
        func date(_ value: Date?) -> String { value.map { $0.formatted(day) } ?? "" }
        let rows = items.map { item -> [String] in
            let container = item.spot?.isContainer == true ? item.spot : nil
            let spot = container?.parent ?? (item.spot?.isContainer == true ? nil : item.spot)
            let warranty = item.primaryWarranty
            let loan = item.activeLoan
            return [
                item.name, item.room?.name ?? "", spot?.name ?? "", container?.name ?? "", item.category,
                item.tags.joined(separator: ", "), String(item.quantity), item.brand, item.model, item.serial,
                item.barcode, item.itemCondition.map(conditionTitle) ?? "", item.price.map(plain) ?? "",
                item.price == nil ? "" : (item.currencyCode.isEmpty ? homeCurrency : item.currencyCode),
                date(item.purchaseDate), item.store, date(warranty?.endDate), warranty?.provider ?? "",
                loan?.personName ?? "", date(loan?.dueAt), date(item.lastConfirmedAt), item.notes,
                item.isPrivate ? "Yes" : "No", date(item.createdAt),
            ]
        }
        return "\u{FEFF}" + ([columns] + rows).map { $0.map(quoted).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// "649.00": always a period and no grouping, whatever the region, so spreadsheets read a number.
    static func plain(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// English, like the column titles.
    static func conditionTitle(_ condition: ItemCondition) -> String {
        switch condition {
        case .new: "New"
        case .likeNew: "Like new"
        case .good: "Good"
        case .fair: "Fair"
        case .worn: "Worn"
        }
    }

    static func quoted(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
