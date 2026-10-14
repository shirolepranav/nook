import Foundation

/// What a room summary in the insurance report may say (R-02, PRD §5 insurance report): the
/// room's own records, nothing else.
public struct RoomFacts: Sendable, Equatable {
    public struct Thing: Sendable, Equatable {
        public var name: String
        public var quantity: Int
        public var category: String

        public init(name: String, quantity: Int = 1, category: String = "") {
            (self.name, self.quantity, self.category) = (name, quantity, category)
        }
    }

    public var room: String
    public var things: [Thing]
    /// The room's total in each currency, never converted (D20).
    public var totals: [(amount: Decimal, currencyCode: String)]

    public init(room: String, things: [Thing], totals: [(amount: Decimal, currencyCode: String)]) {
        (self.room, self.things, self.totals) = (room, things, totals)
    }

    public static func == (lhs: RoomFacts, rhs: RoomFacts) -> Bool {
        lhs.room == rhs.room && lhs.things == rhs.things
            && lhs.totals.map(\.amount) == rhs.totals.map(\.amount) && lhs.totals.map(\.currencyCode) == rhs.totals.map(\.currencyCode)
    }
}

public enum RoomSummary {
    public static let maxLength = 400

    /// The paragraph, or nil unless it's grounded (D55, D56): it names at least one of the
    /// room's things, every number in it is a count, quantity or total from the facts, and
    /// it's short. The user can still edit or clear it before the report is made.
    public static func grounded(_ text: String, in facts: RoomFacts) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxLength else { return nil }
        let lower = text.localizedLowercase
        guard facts.things.contains(where: { lower.contains($0.name.localizedLowercase) }) else { return nil }
        var allowed = Set<Decimal>([Decimal(facts.things.count), Decimal(facts.things.reduce(0) { $0 + $1.quantity })])
        allowed.formUnion(facts.things.map { Decimal($0.quantity) })
        for total in facts.totals {
            allowed.insert(total.amount)
            var whole = Decimal(), amount = total.amount
            NSDecimalRound(&whole, &amount, 0, .plain)
            allowed.insert(whole)
        }
        return numbers(in: text).allSatisfy(allowed.contains) ? text : nil
    }

    /// "$2,608.50" → 2608.5. Grouping commas go; a trailing period ends a sentence.
    static func numbers(in text: String) -> [Decimal] {
        text.matches(of: /\d[\d,.]*/).compactMap { match in
            var digits = String(match.output).replacingOccurrences(of: ",", with: "")
            while digits.hasSuffix(".") { digits.removeLast() }
            return Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX"))
        }
    }
}
