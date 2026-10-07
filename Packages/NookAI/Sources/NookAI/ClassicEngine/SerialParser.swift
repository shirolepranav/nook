import Foundation

/// Ranks a sticker's lines for C-08: labeled serials first, then models, then anything that
/// looks like a code. The user taps the right one; nothing is filled in for them.
public enum SerialParser {
    private static let serialLabel = try! NSRegularExpression(
        pattern: #"^\s*(S\s*/\s*N|SN|SER(IAL)?(\s*(NO|NUMBER|NUM|#))?\.?)\s*[:#.]?\s*"#, options: .caseInsensitive)
    private static let modelLabel = try! NSRegularExpression(
        pattern: #"^\s*(MODEL|MOD|MDL|P\s*/\s*N|PART)(\s*(NO|NUMBER|#))?\.?\s*[:#.]?\s*"#, options: .caseInsensitive)

    public static func read(_ lines: [TextLine]) -> SerialReading {
        let ranked = lines.enumerated().map { order, line -> (SerialReading.Line, Int) in
            let text = line.text.trimmingCharacters(in: .whitespaces)
            if let value = strip(serialLabel, from: text) {
                return (.init(text: text, value: value, kind: .serial, box: line.box), order)
            }
            if let value = strip(modelLabel, from: text) {
                return (.init(text: text, value: value, kind: .model, box: line.box), order)
            }
            return (.init(text: text, value: text, kind: looksLikeCode(text) ? .code : .other, box: line.box), order)
        }
        let rank: (SerialReading.Line.Kind) -> Int = { [.serial: 0, .model: 1, .code: 2, .other: 3][$0]! }
        return SerialReading(lines: ranked.sorted { (rank($0.0.kind), $0.1) < (rank($1.0.kind), $1.1) }.map(\.0))
    }

    /// The text after the label, or nil when the line has no label (or nothing after it).
    private static func strip(_ label: NSRegularExpression, from text: String) -> String? {
        let ns = text as NSString
        guard let match = label.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let value = ns.substring(from: match.range.upperBound).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// One word of 5 or more characters with both letters and digits ("7XK2-48812-QA").
    static func looksLikeCode(_ text: String) -> Bool {
        !text.contains(" ") && text.count >= 5 && text.contains(where: \.isNumber) && text.contains(where: \.isLetter)
    }
}
