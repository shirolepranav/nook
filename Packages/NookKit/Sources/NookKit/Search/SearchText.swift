import Foundation

/// How search reads text (04 §6): case, accents and widths folded, split into words of
/// letters and digits. Shared by the index and the question parser so both see the same words.
enum SearchText {
    static func fold(_ text: String) -> String {
        ItemSuggestions.fold(text)
    }

    static func tokens(_ text: String) -> [String] {
        fold(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// "SN-4471-AB" → "sn4471ab", so a serial typed without its dashes still matches.
    static func compact(_ text: String) -> String {
        fold(text).filter { $0.isLetter || $0.isNumber }
    }

    /// "batteries" → "battery", "boxes" → "box", "keys" → "key". English only, like v1's copy.
    static func singular(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("xes") || word.hasSuffix("ches") || word.hasSuffix("shes") { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }

    /// 04 §6: one typo from 4 letters, two from 8. Short words must be exact.
    static func allowedTypos(_ length: Int) -> Int {
        length >= 8 ? 2 : length >= 4 ? 1 : 0
    }

    /// Damerau-Levenshtein (optimal string alignment), giving up once it passes `limit`;
    /// anything over the limit comes back as `limit + 1`.
    static func distance(_ a: [Unicode.Scalar], _ b: ArraySlice<Unicode.Scalar>, limit: Int) -> Int {
        let (n, m, start) = (a.count, b.count, b.startIndex)
        if abs(n - m) > limit { return limit + 1 }
        if n == 0 || m == 0 { return max(n, m) }
        var older = [Int](repeating: 0, count: m + 1)
        var previous = Array(0...m)
        var current = [Int](repeating: 0, count: m + 1)
        for i in 1...n {
            current[0] = i
            var rowMin = i
            for j in 1...m {
                let cost = a[i - 1] == b[start + j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[start + j - 2], a[i - 2] == b[start + j - 1] {
                    value = min(value, older[j - 2] + 1)
                }
                current[j] = value
                rowMin = min(rowMin, value)
            }
            if rowMin > limit { return limit + 1 }
            (older, previous, current) = (previous, current, older)
        }
        return min(previous[m], limit + 1)
    }
}
