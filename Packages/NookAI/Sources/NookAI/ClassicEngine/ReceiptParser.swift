import CoreGraphics
import Foundation

/// Finds the amounts, dates, store and currency on a receipt's lines (C-06, Classic). Pure
/// Swift, so it's tested on text alone (ReceiptParserTests).
public enum ReceiptParser {
    public static func read(_ lines: [TextLine], homeCurrency: String = Locale.current.currency?.identifier ?? "USD",
                            now: Date = .now, locale: Locale = .current) -> ReceiptReading {
        let rows = rowTexts(lines)
        var amounts: [(candidate: ReceiptReading.Candidate<Decimal>, score: Int, order: Int)] = []
        var dates: [(candidate: ReceiptReading.Candidate<Date>, score: Int, order: Int)] = []
        var symbols: [String] = []
        let monthFirst = monthComesFirst(in: locale)
        for (order, line) in lines.enumerated() {
            let label = rows[order]
            for found in amountMatches(in: line.text, isTotalRow: amountScore(label) == 3) {
                if let symbol = found.symbol { symbols.append(symbol) }
                amounts.append((.init(value: found.value, text: found.text, page: line.page,
                                      box: subBox(line, found.range)), amountScore(label), order))
            }
            for found in dateMatches(in: line.text, monthFirst: monthFirst, now: now) {
                let score = label.contains("DATE") || label.contains("DATUM") ? 1 : 0
                dates.append((.init(value: found.value, text: found.text, page: line.page,
                                    box: subBox(line, found.range)), score, order))
            }
        }
        // ponytail: thousands spaced with a plain space ("1 234,56") read as two numbers; a
        // space also sits between a quantity and a price, which matters more.
        // TOTAL first; among equals the larger amount (cash given back is labeled, so it
        // ranks lower), then the later line.
        amounts.sort { ($0.score, $0.candidate.value, $0.order) > ($1.score, $1.candidate.value, $1.order) }
        // A DATE line first, then the first date on the receipt.
        dates.sort { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
        return ReceiptReading(lines: lines, amounts: amounts.map(\.candidate), dates: dates.map(\.candidate),
                              store: store(in: lines, locale: locale),
                              currencyCode: currency(symbols, home: homeCurrency))
    }

    // MARK: Amounts

    struct Found<Value> {
        var value: Value
        var text: String
        var range: Range<String.Index>
        var symbol: String?
    }

    private static let symbols = "[$€£¥₹]"
    /// A number (Indian lakh grouping included) not touching other digits, slashes, colons or percent signs, so dates, times,
    /// phone numbers and tax rates stay out.
    private static let amountPattern = try! NSRegularExpression(pattern: """
        (?<pre>\(symbols)|\\b[A-Z]{3}\\b|\\bRs\\.?)?\\s?\
        (?<![\\d/.,:-])(?<num>\\d{1,2}(?:,\\d{2})+,\\d{3}(?:\\.\\d{2})?|\\d{1,3}(?:[,.'\\u00A0]\\d{3})+(?:[.,]\\d{1,2})?|\\d+(?:[.,]\\d{1,2})?)\
        (?![\\d/:%]|[.,]\\d)\
        (?:\\s?(?<post>\(symbols)|\\b[A-Z]{3}\\b))?
        """)

    static func amountMatches(in text: String, isTotalRow: Bool = false) -> [Found<Decimal>] {
        let ns = text as NSString
        return amountPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let part = { (name: String) -> String? in
                let range = match.range(withName: name)
                return range.location == NSNotFound ? nil : ns.substring(with: range)
            }
            guard let number = part("num"), let range = Range(match.range(withName: "num"), in: text) else { return nil }
            let symbol = [part("pre"), part("post")].compactMap { $0 }.first(where: isCurrency)
            let hasCents = number.range(of: #"[.,]\d{2}$"#, options: .regularExpression) != nil
            // A plain whole number is a quantity or a code unless a currency is printed with it,
            // or it's on a TOTAL row (a ¥ or ₹ the reader missed, D48).
            guard hasCents || symbol != nil || isTotalRow, let value = decimal(number), value > 0 else { return nil }
            return Found(value: value, text: (symbol.map { $0 } ?? "") + number, range: range, symbol: symbol)
        }
    }

    /// "1,234.56" and "1.234,56" are both 1234.56; the last separator before 1–2 digits is
    /// the decimal point.
    static func decimal(_ text: String) -> Decimal? {
        let separators: Set<Character> = [".", ","]
        var whole = text, fraction = ""
        if let last = text.lastIndex(where: { separators.contains($0) }) {
            let after = text[text.index(after: last)...]
            if (1...2).contains(after.count) {
                whole = String(text[..<last])
                fraction = String(after)
            }
        }
        let digits = whole.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Decimal(string: fraction.isEmpty ? digits : digits + "." + fraction, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func isCurrency(_ symbol: String) -> Bool {
        symbol.count == 1 || symbol.hasPrefix("Rs") || Locale.commonISOCurrencyCodes.contains(symbol)
    }

    private static func amountScore(_ row: String) -> Int {
        if ["CHANGE", "CASH", "TENDER", "DISCOUNT", "SAVINGS", "RÜCKGELD"].contains(where: row.contains) { return -1 }
        if row.range(of: #"SUB[\s-]?TOTAL|ZWISCHENSUMME"#, options: .regularExpression) != nil { return 2 }
        if ["TAX", "VAT", "MWST", "GST", "TVA", "IVA"].contains(where: row.contains) { return 0 }
        if ["TOTAL", "AMOUNT DUE", "BALANCE DUE", "SUMME", "GESAMT", "TOTALE", "MONTANT", "TOTAAL", "合計"]
            .contains(where: row.contains) { return 3 }
        return 1
    }

    // MARK: Dates

    private static let numericDate = try! NSRegularExpression(
        pattern: #"(?<![\d/.-])(\d{1,4})[./-](\d{1,2})[./-](\d{2,4})(?![\d/-]|\.\d)"#)
    private static let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    static func dateMatches(in text: String, monthFirst: Bool, now: Date) -> [Found<Date>] {
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)
        var found: [Found<Date>] = []
        // Numbers: ISO year first, else the locale's order unless a part over 12 settles it.
        for match in numericDate.matches(in: text, range: all) {
            let parts = (1...3).map { ns.substring(with: match.range(at: $0)) }
            guard let a = Int(parts[0]), let b = Int(parts[1]), var c = Int(parts[2]) else { continue }
            var (year, month, day): (Int, Int, Int)
            if parts[0].count == 4 {
                (year, month, day) = (a, b, c)
            } else {
                if parts[2].count == 2 { c += 2000 } else if parts[2].count != 4 { continue }
                if a > 12 { (month, day) = (b, a) } else if b > 12 { (month, day) = (a, b) }
                else { (month, day) = monthFirst ? (a, b) : (b, a) }
                year = c
            }
            guard let date = makeDate(year, month, day), let range = Range(match.range, in: text) else { continue }
            found.append(Found(value: date, text: ns.substring(with: match.range), range: range))
        }
        // Written months ("Sep 14, 2026", "14 Sept 2026"): only matches with letters, so a
        // time like 14:32 isn't read as today.
        for match in detector.matches(in: text, range: all) {
            let matched = ns.substring(with: match.range)
            guard matched.contains(where: \.isLetter), let date = match.date,
                  let range = Range(match.range, in: text),
                  !found.contains(where: { $0.range.overlaps(range) }) else { continue }
            let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
            guard let clean = makeDate(day.year!, day.month!, day.day!) else { continue }
            found.append(Found(value: clean, text: matched, range: range))
        }
        // Never in the future; nothing before 1980 either.
        let latest = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return found.filter { $0.value <= latest && $0.value >= makeDate(1980, 1, 1)! }
    }

    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: Calendar.current) else { return nil }
        return Calendar.current.date(from: components)
    }

    static func monthComesFirst(in locale: Locale) -> Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? "M/d/y"
        guard let month = format.firstIndex(of: "M"), let day = format.firstIndex(of: "d") else { return true }
        return month < day
    }

    // MARK: Store and currency

    /// The first line that's mostly letters, in title case if it was printed in capitals.
    private static func store(in lines: [TextLine], locale: Locale) -> String? {
        let skip = ["RECEIPT", "WELCOME", "INVOICE", "THANK", "COPY", "ORDER"]
        for line in lines.prefix(8) {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let visible = text.filter { !$0.isWhitespace }
            let letters = visible.filter(\.isLetter).count
            guard letters >= 3, Double(letters) / Double(visible.count) >= 0.6,
                  !skip.contains(where: text.uppercased().contains) else { continue }
            return text == text.uppercased() ? text.capitalized(with: locale) : text
        }
        return nil
    }

    private static func currency(_ symbols: [String], home: String) -> String {
        let dollars = ["USD", "CAD", "AUD", "NZD", "SGD", "HKD", "MXN"]
        // The symbol printed most often wins.
        let counts = Dictionary(symbols.map { ($0, 1) }, uniquingKeysWith: +)
        guard let symbol = counts.max(by: { $0.value < $1.value })?.key else { return home }
        switch symbol {
        case "$": return dollars.contains(home) ? home : "USD"
        case "€": return "EUR"
        case "£": return "GBP"
        case "¥": return home == "CNY" ? "CNY" : "JPY"
        case "₹", "Rs", "Rs.": return "INR"
        default: return symbol
        }
    }

    // MARK: Rows

    /// Each line's row text, uppercased: lines side by side on the page ("TOTAL" … "708.00")
    /// are one row, so a label far left still labels the number far right.
    private static func rowTexts(_ lines: [TextLine]) -> [String] {
        lines.indices.map { index in
            let line = lines[index]
            return lines.indices.filter { other in
                other == index || lines[other].page == line.page
                    && abs(lines[other].level - line.level) < max(line.box.height, lines[other].box.height) / 2
            }
            .map { lines[$0].text }.joined(separator: " ").uppercased()
        }
    }

    /// The part of a line's box under `range`, by character count.
    private static func subBox(_ line: TextLine, _ range: Range<String.Index>) -> CGRect {
        let count = CGFloat(max(line.text.count, 1))
        let start = CGFloat(line.text.distance(from: line.text.startIndex, to: range.lowerBound))
        let length = CGFloat(line.text.distance(from: range.lowerBound, to: range.upperBound))
        return CGRect(x: line.box.minX + line.box.width * start / count, y: line.box.minY,
                      width: line.box.width * length / count, height: line.box.height)
    }
}
