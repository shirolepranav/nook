import Foundation

/// What a value estimate is asked about (D16): the item as the editor has it now.
public struct ValueSubject: Sendable, Equatable {
    public var name: String
    public var category: String
    public var brand: String?
    public var condition: String?
    public var price: Decimal?
    public var purchaseDate: Date?
    public var currencyCode: String

    public init(name: String, category: String = "", brand: String? = nil, condition: String? = nil,
                price: Decimal? = nil, purchaseDate: Date? = nil, currencyCode: String) {
        (self.name, self.category, self.brand, self.condition) = (name, category, brand, condition)
        (self.price, self.purchaseDate, self.currencyCode) = (price, purchaseDate, currencyCode)
    }
}

/// "$420–$510", always labeled "Estimate" (PRD §5, D16). Only the AI path makes one.
public struct ValueEstimate: Sendable, Equatable {
    public let low: Decimal
    public let high: Decimal

    /// Nil unless the range is believable: positive, in order, and not wider than 20 times
    /// its low end (D55). Whole units: an estimate doesn't need cents.
    public init?(low: Double, high: Double) {
        guard low.isFinite, high.isFinite, low > 0, high >= low, high <= low * 20 else { return nil }
        self.low = Decimal(low.rounded())
        self.high = Decimal(high.rounded())
        guard self.low > 0 else { return nil }
    }
}
