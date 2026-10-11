import CoreGraphics
import FoundationModels

/// One thing the model spotted in a photo (PRD §8), for a room scan's card (C-03) or a quick
/// add's prefill (C-05). The model fills it; Classic never returns one. Every field is a
/// suggestion the user can edit (PRD §6).
@Generable(description: "One household item visible in the photo")
public struct DetectedItem: Sendable, Equatable {
    @Guide(description: "Short everyday name, for example 'Coffee machine'")
    public var name: String

    @Guide(description: "The closest category", .anyOf(DetectedItem.categories))
    public var category: String

    @Guide(description: "The brand only when its name or logo is clearly visible")
    public var brand: String?

    @Guide(description: "How worn it looks", .anyOf(["new", "likeNew", "good", "fair", "worn"]))
    public var condition: String?

    // D53: the model estimates where the item is, since Foundation Models has no boxes of its
    // own. `box` checks the estimate before anything draws it.
    @Guide(description: "Left edge of the item, as a fraction of the photo's width", .range(0...1))
    public var left: Double?
    @Guide(description: "Top edge of the item, as a fraction of the photo's height", .range(0...1))
    public var top: Double?
    @Guide(description: "Width of the item, as a fraction of the photo's width", .range(0...1))
    public var width: Double?
    @Guide(description: "Height of the item, as a fraction of the photo's height", .range(0...1))
    public var height: Double?

    public init(name: String, category: String, brand: String? = nil, condition: String? = nil, box: CGRect? = nil) {
        (self.name, self.category, self.brand, self.condition) = (name, category, brand, condition)
        (left, top, width, height) = (box.map { $0.minX }, box.map { $0.minY }, box.map { $0.width }, box.map { $0.height })
    }

    /// The categories new items use, from `Nook/Resources/common-items.json` (D53).
    public static let categories = [
        "Appliances", "Bedding & Bath", "Cleaning & Storage", "Clothing", "Collectibles", "Decor", "Documents",
        "Electronics", "Furniture", "Garden & Outdoor", "Jewelry", "Kids & Baby", "Kitchen", "Music", "Office",
        "Pets", "Sports", "Tools", "Vehicle",
    ]

    /// Where it is, normalized with a top-left origin, or nil when the estimate can't be
    /// trusted: missing, too small to tap, or most of the photo (then the card uses the whole
    /// photo, like "Add Item by Name").
    public var box: CGRect? {
        guard let left, let top, let width, let height else { return nil }
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let box = CGRect(x: left, y: top, width: width, height: height).intersection(unit)
        guard !box.isNull, box.width >= 0.03, box.height >= 0.03, box.width * box.height <= 0.9 else { return nil }
        return box
    }
}
