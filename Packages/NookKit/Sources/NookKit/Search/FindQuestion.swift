import Foundation

/// The Classic reading of what was typed in Find (PRD §6): a plain search or an everyday
/// question, turned into search words and what kind of answer fits. English only, like
/// v1's copy. Answers still come only from records; this only picks the words.
public struct FindQuestion: Sendable, Equatable {
    public enum Intent: Sendable, Equatable {
        /// "Where are the passports?", or any plain search.
        case locate
        /// "Who has my drill?"
        case who
        /// "What's in the garage?"
        case contents
        /// "Do I have any AA batteries?"
        case quantity
    }

    public let intent: Intent
    public let terms: [String]

    init(intent: Intent, terms: [String]) {
        (self.intent, self.terms) = (intent, terms)
    }

    public init(_ text: String) {
        let words = SearchText.tokens(text)
        let phrase = words.joined(separator: " ")
        func starts(_ prefixes: [String]) -> Bool { prefixes.contains { phrase.hasPrefix($0 + " ") } }
        intent = if starts(["who has", "who s got", "who borrowed"]) {
            .who
        } else if starts(["what s in", "whats in", "what is in", "what s inside", "what is inside"]) {
            .contents
        } else if starts(["do i have", "do we have", "have i got", "how many"]) {
            .quantity
        } else {
            .locate
        }
        let kept = words.filter { !Self.stopWords.contains($0) }
        // A search made only of small words ("in", "the") still searches for them.
        terms = kept.isEmpty ? words : kept
    }

    static let stopWords: Set<String> = [
        "where", "wheres", "is", "are", "was", "were", "my", "our", "the", "a", "an", "did", "i", "we",
        "put", "do", "does", "have", "has", "had", "any", "some", "what", "whats", "s", "in", "inside",
        "who", "got", "borrowed", "how", "many", "much", "me", "find", "of", "it", "them", "they", "on",
        "at", "left", "keep", "kept", "can", "you", "to", "into", "there", "please",
    ]
}
