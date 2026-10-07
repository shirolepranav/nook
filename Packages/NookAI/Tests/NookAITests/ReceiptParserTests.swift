import Foundation
import Testing
@testable import NookAI

/// Lines stacked one per row, so labels and numbers on a line share a row.
func lines(_ texts: [String]) -> [TextLine] {
    texts.enumerated().map { TextLine(text: $1, box: CGRect(x: 0.1, y: Double($0) * 0.05, width: 0.8, height: 0.04)) }
}

let us = Locale(identifier: "en_US"), de = Locale(identifier: "de_DE")
let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7))!

func day(_ y: Int, _ m: Int, _ d: Int) -> Date { Calendar.current.date(from: DateComponents(year: y, month: m, day: d))! }

func read(_ texts: [String], home: String = "USD", locale: Locale = us) -> ReceiptReading {
    ReceiptParser.read(lines(texts), homeCurrency: home, now: now, locale: locale)
}

@Test func totalBeatsSubtotalTaxAndCash() {
    let reading = read(["HOME GOODS CO.", "ESPRESSO 649.00", "SUBTOTAL 708.00", "TAX 8.25% 58.41",
                        "TOTAL $766.41", "CASH 800.00", "CHANGE 33.59"])
    #expect(reading.amounts.first?.value == Decimal(string: "766.41"))
    #expect(reading.amounts.map(\.value).contains(Decimal(string: "8.25")) == false)   // a rate, not money
    #expect(reading.store == "Home Goods Co.")
    #expect(reading.currencyCode == "USD")
}

@Test func labelOnItsOwnLineStillLabelsTheRow() {
    var split = lines(["TOTAL", "708.00", "CASH", "900.00"])
    split[1].level = split[0].level   // "708.00" sits beside "TOTAL"
    split[3].level = split[2].level
    #expect(ReceiptParser.read(split, homeCurrency: "USD", now: now, locale: us).amounts.first?.value == 708)
}

@Test(arguments: [
    ("TOTAL 1,234.56", "1234.56"), ("SUMME 1.234,56", "1234.56"), ("TOTAL 89,90 €", "89.90"),
    ("TOTAL ¥14,080", "14080"), ("TOTAL ₹1,45,999.00", "145999.00"), ("Total £21.49", "21.49"),
    ("TOTAL EUR 12.00", "12.00"), ("TOTAL 1'299.00", "1299.00"),
])
func amountsInEveryFormat(line: String, expected: String) {
    #expect(read([line]).amounts.first?.value == Decimal(string: expected))
}

@Test(arguments: [("$", "USD", "USD"), ("$", "CAD", "CAD"), ("€", "USD", "EUR"), ("£", "USD", "GBP"),
                  ("¥", "USD", "JPY"), ("₹", "USD", "INR"), ("", "EUR", "EUR")])
func currencyFromTheSymbol(symbol: String, home: String, expected: String) {
    #expect(read(["TOTAL \(symbol)12.00"], home: home).currencyCode == expected)
}

@Test func wholeNumbersNeedACurrency() {
    #expect(read(["QTY 2", "STORE 1042", "TEL 555-1234"]).amounts.isEmpty)
}

@Test(arguments: [
    ("09/14/2026", us, day(2026, 9, 14)), ("14/09/2026", us, day(2026, 9, 14)),
    ("03/04/2026", us, day(2026, 3, 4)), ("03.04.2026", de, day(2026, 4, 3)),
    ("2026-06-21", us, day(2026, 6, 21)), ("11/30/25", us, day(2025, 11, 30)),
    ("19-01-2026", de, day(2026, 1, 19)), ("Sep 3, 2026", us, day(2026, 9, 3)),
    ("28 March 2026", us, day(2026, 3, 28)), ("14 Sep 2026 10:15", us, day(2026, 9, 14)),
])
func datesInEveryFormat(text: String, locale: Locale, expected: Date) {
    #expect(read(["Shop", text], locale: locale).dates.first?.value == expected)
}

@Test func futureDatesAndTimesAreNotDates() {
    let reading = read(["Shop", "12/25/2027", "14:32", "Valid until 2030-01-01"])
    #expect(reading.dates.isEmpty)
}

@Test func aDateLabelWins() {
    let reading = read(["Shop", "Printed 2026-09-20", "Purchase date: 2026-09-14"])
    #expect(reading.dates.first?.value == day(2026, 9, 14))
}

@Test func datesDoNotBecomeAmounts() {
    #expect(read(["12.09.2026", "14.09.26"], locale: de).amounts.isEmpty)
}

@Test func highlightBoxCoversTheNumber() {
    let reading = read(["TOTAL 708.00"])
    let box = try! #require(reading.amounts.first?.box)
    #expect(box.minX > 0.1 && box.maxX <= 0.9 + 0.001 && box.width < 0.8)
}
