import Foundation

/// One search result, best first.
public struct SearchHit: Sendable, Hashable {
    public let id: UUID
    public let kind: SearchDoc.Kind
    public let isPrivate: Bool
    public let score: Double
}

/// The Classic search index (04 §6, F5): an in-memory word index over value snapshots. It's
/// immutable and `Sendable`, so a rebuilt one simply replaces the old, and queries run off
/// the main actor (D46). Budget: under 100 ms per keystroke at 5,000 items.
///
/// Matching, per word: exact, prefix ("pass" → "Passport"), a typo (one from 4 letters, two
/// from 8; against the start of longer words from 5), then synonyms ("fob" → "key"). Every
/// word must match; if none do together, the best partial matches come back instead.
/// Ranking: exact name > name prefix > tag > synonym > room/spot > details > receipt text,
/// with a small boost for recently confirmed items.
public struct SearchIndex: Sendable {
    private enum Field: Sendable {
        case name, tag, place, detail, receipt

        var weight: Double {
            switch self {
            case .name: 50
            case .tag: 30
            case .place: 15
            case .detail: 10
            case .receipt: 5
            }
        }
    }

    private enum Match {
        static let exact = 1.0
        static let prefix = 0.8
        static let typo = 0.6
        static let synonym = 0.4
    }

    private struct Posting: Sendable {
        let doc: Int
        let field: Field
    }

    public let docs: [SearchDoc]
    private let names: [String]                     // folded, for the exact-name bonus
    private let vocabulary: [String]                // sorted, for prefix lookups
    private let scalars: [[Unicode.Scalar]]         // the vocabulary, for typo distances
    private let postings: [String: [Posting]]
    private let synonyms: Synonyms

    public static let empty = SearchIndex(docs: [])

    public init(docs: [SearchDoc], synonyms: Synonyms = .none) {
        var postings: [String: [Posting]] = [:]
        for (index, doc) in docs.enumerated() {
            var seen = Set<String>()
            func add(_ text: String, _ field: Field) {
                for token in SearchText.tokens(text) where seen.insert(token).inserted {
                    postings[token, default: []].append(Posting(doc: index, field: field))
                }
            }
            // Strongest field first, so a word in both the name and a tag counts as the name.
            add(doc.name, .name)
            for tag in doc.tags { add(tag, .tag) }
            add(doc.category, .tag)
            add(doc.path, .place)
            for detail in doc.details { add(detail, .detail) }
            for code in doc.codes { add(code, .detail); add(SearchText.compact(code), .detail) }
            add(doc.receiptText, .receipt)
        }
        self.docs = docs
        self.names = docs.map { SearchText.fold($0.name) }
        self.vocabulary = postings.keys.sorted()
        self.scalars = vocabulary.map { Array($0.unicodeScalars) }
        self.postings = postings
        self.synonyms = synonyms
    }

    /// Searches for what was typed. Empty text with a filter lists every item that passes it,
    /// by name.
    public func search(_ text: String, filter: SearchFilter = SearchFilter(), homeCurrency: String = "",
                       now: Date = .now, limit: Int = 50) -> [SearchHit] {
        search(terms: SearchText.tokens(text), filter: filter, homeCurrency: homeCurrency, now: now, limit: limit)
    }

    /// Searches for words already picked out (`FindQuestion.terms`).
    public func search(terms: [String], filter: SearchFilter = SearchFilter(), homeCurrency: String = "",
                       now: Date = .now, limit: Int = 50) -> [SearchHit] {
        let terms = terms.map(SearchText.fold).filter { !$0.isEmpty }
        let passes: (Int) -> Bool = filter.isEmpty
            ? { _ in true }
            : { filter.matches(docs[$0], homeCurrency: homeCurrency, now: now) }

        guard !terms.isEmpty else {
            guard !filter.isEmpty else { return [] }
            return docs.indices.filter(passes)
                .sorted { names[$0] < names[$1] }
                .prefix(limit)
                .map { hit($0, score: 0) }
        }

        let perTerm = terms.map(scores(for:))
        var combined = perTerm[0]
        for scores in perTerm.dropFirst() {
            combined = combined.reduce(into: [:]) { result, entry in
                if let other = scores[entry.key] { result[entry.key] = entry.value + other }
            }
        }
        // "I put the passports in the safe" has no single match; show what matches best.
        if combined.isEmpty, perTerm.count > 1 {
            combined = perTerm.reduce(into: [:]) { result, scores in result.merge(scores, uniquingKeysWith: +) }
        }

        let phrase = terms.joined(separator: " ")
        let year = 365.0 * 86_400
        let ranked = combined.compactMap { index, score -> (Int, Double)? in
            guard passes(index) else { return nil }
            var total = score
            if names[index] == phrase { total += 100 } else if names[index].hasPrefix(phrase) { total += 20 }
            let age = now.timeIntervalSince(docs[index].lastConfirmedAt)
            total += 5 * max(0, 1 - age / year)
            return (index, total)
        }
        return ranked
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : names[$0.0] < names[$1.0] }
            .prefix(limit)
            .map { hit($0.0, score: $0.1) }
    }

    // MARK: Private

    private func hit(_ index: Int, score: Double) -> SearchHit {
        SearchHit(id: docs[index].id, kind: docs[index].kind, isPrivate: docs[index].isPrivate, score: score)
    }

    /// The best score each document gets for one word.
    private func scores(for term: String) -> [Int: Double] {
        var best: [Int: Double] = [:]
        func add(_ token: String, _ match: Double) {
            for posting in postings[token] ?? [] {
                let score = posting.field.weight * match
                if score > best[posting.doc, default: 0] { best[posting.doc] = score }
            }
        }
        // Exact and prefix; the singular only as a whole word ("passports" → "passport"),
        // or "skis" → "ski" would find "skillet".
        var index = lowerBound(term)
        while index < vocabulary.count, vocabulary[index].hasPrefix(term) {
            add(vocabulary[index], vocabulary[index] == term ? Match.exact : Match.prefix)
            index += 1
        }
        let singular = SearchText.singular(term)
        if singular != term { add(singular, Match.exact) }
        // Typos, against whole words, and from 5 letters against the start of longer ones
        // ("paspo" → "passport"); at 4, "skis" would match the start of "skillet".
        let limit = SearchText.allowedTypos(term.count)
        if limit > 0 {
            let query = Array(term.unicodeScalars)
            for (index, word) in scalars.enumerated() where word.count + limit >= query.count {
                var distance = SearchText.distance(query, word[...], limit: limit)
                // A missing or extra letter shifts the length, so try starts one shorter and longer.
                if distance > limit, query.count >= 5, word.count > query.count {
                    for length in (query.count - 1)...min(query.count + 1, word.count - 1) {
                        distance = min(distance, SearchText.distance(query, word.prefix(length), limit: limit))
                    }
                }
                if distance > 0, distance <= limit { add(vocabulary[index], Match.typo) }
            }
        }
        for synonym in synonyms.expansions(of: term) { add(synonym, Match.synonym) }
        return best
    }

    private func lowerBound(_ word: String) -> Int {
        var (low, high) = (0, vocabulary.count)
        while low < high {
            let mid = (low + high) / 2
            if vocabulary[mid] < word { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
