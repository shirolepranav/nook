import Foundation

/// A value snapshot of one searchable thing (04 §6). The index is built from these off the
/// main actor, so it never touches SwiftData models (D46).
public struct SearchDoc: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable { case item, room, spot, container }

    public var id: UUID
    public var kind: Kind
    public var name: String
    public var tags: [String]
    public var category: String
    /// Brand and notes.
    public var details: [String]
    /// Model, serial and barcode: matched word by word and with separators removed.
    public var codes: [String]
    public var receiptText: String
    /// Where it is: an item's place, or the room (and spot) a spot or container sits in.
    public var path: String
    public var roomID: UUID?
    public var isPrivate: Bool
    public var quantity: Int
    public var price: Decimal?
    public var currencyCode: String
    public var lastConfirmedAt: Date
    public var isLent: Bool
    /// The latest end date of the item's warranties (F4).
    public var warrantyEnd: Date?

    public init(id: UUID, kind: Kind, name: String, tags: [String] = [], category: String = "",
                details: [String] = [], codes: [String] = [], receiptText: String = "", path: String = "",
                roomID: UUID? = nil, isPrivate: Bool = false, quantity: Int = 1, price: Decimal? = nil,
                currencyCode: String = "", lastConfirmedAt: Date = .distantPast, isLent: Bool = false,
                warrantyEnd: Date? = nil) {
        (self.id, self.kind, self.name, self.tags, self.category) = (id, kind, name, tags, category)
        (self.details, self.codes, self.receiptText, self.path, self.roomID) = (details, codes, receiptText, path, roomID)
        (self.isPrivate, self.quantity, self.price, self.currencyCode) = (isPrivate, quantity, price, currencyCode)
        (self.lastConfirmedAt, self.isLent, self.warrantyEnd) = (lastConfirmedAt, isLent, warrantyEnd)
    }
}
