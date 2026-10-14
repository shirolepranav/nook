import Foundation
import SwiftData
import Testing
@testable import NookKit

// F9: the insurance report's data and the CSV export (P10).

@MainActor @Test func reportGroupsByRoomWithTotalsPerCurrency() throws {
    let f = try HomeFixture()
    let report = try ReportSnapshot.make(ReportOptions(), context: f.context, homeCurrency: "USD")
    #expect(report.sections.map(\.name) == ["Kitchen", "Garage", ""])   // Home's order, no room last
    #expect(report.itemCount == 5)                                       // the deleted fan is left out
    let kitchen = try #require(report.sections.first)
    #expect(kitchen.lines.map(\.name) == ["Espresso machine", "Mug, \"Best Dad\""])   // by place, then name
    #expect(kitchen.lines.last?.place == "Counter → Bread bin")
    #expect(kitchen.totals == [Money(649, "USD"), Money(12.5, "EUR")])   // home currency first (D20)
    #expect(report.totals == [Money(2_608, "USD"), Money(12.5, "EUR")])
    #expect(report.isMixed(homeCurrency: "USD"))
    #expect(report.sections[1].lines.contains { $0.name == "Grandma’s ring" })   // Private is the owner's (D56)
    #expect(report.receipts.map(\.itemName) == ["Espresso machine"])
}

@MainActor @Test func reportScopes() throws {
    let f = try HomeFixture()
    let garage = try #require(try f.context.fetch(FetchDescriptor<Room>()).first { $0.name == "Garage" })
    let rooms = try ReportSnapshot.make(ReportOptions(scope: .rooms([garage.id])), context: f.context, homeCurrency: "USD")
    #expect(rooms.sections.map(\.name) == ["Garage"])
    let drill = try #require(rooms.sections[0].lines.first { $0.name == "Cordless drill" })
    let one = try ReportSnapshot.make(ReportOptions(scope: .item(drill.id)), context: f.context, homeCurrency: "USD")
    #expect(one.itemCount == 1 && one.totals == [Money(159, "USD")])
    let bare = try ReportSnapshot.make(ReportOptions(receipts: false), context: f.context, homeCurrency: "USD")
    #expect(bare.receipts.isEmpty)
}

@Test func csvQuotesOnlyWhatNeedsIt() {
    #expect(CSVExport.quoted("Drill") == "Drill")
    #expect(CSVExport.quoted("Mug, \"Best\"") == "\"Mug, \"\"Best\"\"\"")
    #expect(CSVExport.quoted("a\nb") == "\"a\nb\"")
    #expect(CSVExport.plain(Decimal(string: "1234.5")!) == "1234.50")
}

/// The golden file is the whole export of `HomeFixture`. Record a new one with
/// `NOOK_RECORD_GOLDEN=1 swift test --filter csvMatchesGolden`, then read the diff.
@MainActor @Test func csvMatchesGolden() throws {
    let f = try HomeFixture()
    let items = try f.context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil },
                                                          sortBy: [SortDescriptor(\.name)]))
    let csv = CSVExport.csv(items, homeCurrency: "USD", timeZone: TimeZone(identifier: "UTC")!)
    let golden = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appending(path: "../../../../Fixtures/golden/home.csv").standardized
    if ProcessInfo.processInfo.environment["NOOK_RECORD_GOLDEN"] == "1" {
        try FileManager.default.createDirectory(at: golden.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(csv.utf8).write(to: golden)
    }
    #expect(csv == String(decoding: try Data(contentsOf: golden), as: UTF8.self))
    #expect(csv.hasPrefix("\u{FEFF}Name,Room,Spot,Container,"))
    #expect(csv.components(separatedBy: "\r\n").first?.split(separator: ",").count == 24)
}
