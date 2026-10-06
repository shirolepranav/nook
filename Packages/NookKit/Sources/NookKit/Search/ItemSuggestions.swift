import Foundation

/// One entry of the built-in list of 500 common household items (PRD §5,
/// `Nook/Resources/common-items.json`). Classic manual tagging reuses it (P6).
public struct CommonItem: Codable, Hashable, Sendable {
    public let name: String
    public let category: String

    public init(name: String, category: String) {
        (self.name, self.category) = (name, category)
    }

    public static func load(from url: URL?) -> [CommonItem] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CommonItem].self, from: data)) ?? []
    }
}

/// Name autocomplete for the item editor (I-02): the user's past names first, then common
/// items. Starts at the first letter and matches the start of any word, ignoring case and
/// accents ("cafe" finds "Café press").
public enum ItemSuggestions {
    public static func suggestions(for text: String, past: [String], common: [CommonItem],
                                   limit: Int = 3) -> [String] {
        let query = fold(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.isEmpty else { return [] }
        var seen: Set<String> = [query]   // never suggest exactly what's typed
        var results: [String] = []
        for name in past + common.map(\.name) where results.count < limit {
            let folded = fold(name)
            guard matches(folded, query), seen.insert(folded).inserted else { continue }
            results.append(name)
        }
        return results
    }

    /// The category of a common item with this name, for filling an empty category.
    public static func category(for name: String, in common: [CommonItem]) -> String? {
        let folded = fold(name)
        return common.first { fold($0.name) == folded }?.category
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private static func matches(_ name: String, _ query: String) -> Bool {
        if name.hasPrefix(query) { return true }
        return name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains { $0.hasPrefix(query) }
    }
}
