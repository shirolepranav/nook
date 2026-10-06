import Foundation

/// The built-in synonym list (PRD §6, `Nook/Resources/synonyms.json`): groups of words that
/// mean the same thing at home, so "fob" finds "Spare car key" without any AI.
public struct Synonyms: Sendable {
    private let map: [String: [String]]

    public static let none = Synonyms(groups: [])

    /// Each group is a set of single words, e.g. `["key", "fob", "keyfob"]`.
    public init(groups: [[String]]) {
        var map: [String: [String]] = [:]
        for group in groups {
            let words = group.map(SearchText.fold)
            for word in words { map[word, default: []] += words.filter { $0 != word } }
        }
        self.map = map
    }

    public static func load(from url: URL?) -> Synonyms {
        guard let url, let data = try? Data(contentsOf: url),
              let groups = try? JSONDecoder().decode([[String]].self, from: data) else { return .none }
        return Synonyms(groups: groups)
    }

    /// The other words for `word` (already folded), trying its singular too.
    func expansions(of word: String) -> [String] {
        map[word] ?? map[SearchText.singular(word)] ?? []
    }
}
