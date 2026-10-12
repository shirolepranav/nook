import CoreGraphics
import FoundationModels
import NaturalLanguage
import NookKit
import Vision

// The OCR and barcode tools offered to the model during a room scan (PRD §8 step 3), so it can
// read a brand on a box or a code on a label. Both read the photo being scanned.

@Generable
struct NoArguments {}

struct ReadLabels: Tool {
    let image: CGImage
    let description = "Reads the printed text visible in the photo, one line each."

    func call(arguments: NoArguments) async throws -> String {
        // ponytail: the 60 most confident lines; a cluttered shelf has more, and the model needs few.
        try await TextReader.lines(in: image)
            .sorted { $0.confidence > $1.confidence }
            .prefix(60)
            .map(\.text)
            .joined(separator: "\n")
    }
}

struct ReadBarcodes: Tool {
    let image: CGImage
    let description = "Reads retail barcodes (EAN and UPC) visible in the photo."

    func call(arguments: NoArguments) async throws -> String {
        let codes = try await DetectBarcodesRequest().perform(on: image)
            .compactMap(\.payloadString)
            .filter(EAN.isValid)
        return codes.isEmpty ? "No barcodes." : codes.joined(separator: "\n")
    }
}

/// Find's one tool (PRD §6): the model looks names up here, so it answers with words that are
/// really saved. Private items are never in it (`SearchIndex.records`, PRD §9).
struct LookUp: Tool {
    let index: SearchIndex
    let description = "Finds things and places saved in the home inventory. Gives each match's name, kind and where it is."

    @Generable
    struct Arguments {
        @Guide(description: "A few words naming a thing or a place")
        var words: String
    }

    func call(arguments: Arguments) async throws -> String {
        var found = index.records(matching: arguments.words)
        if found.isEmpty { found = NearWords.records(for: arguments.words, in: index) }
        guard !found.isEmpty else { return "Nothing saved by that name." }
        return found.map { "\($0.name) (\($0.kind)) – \($0.path)" }.joined(separator: "\n")
    }
}

/// Loose wording (D55): "clicker" finds "Remote", "comforter" finds "Duvet". When a word finds
/// nothing, its nearest saved words by meaning are searched instead. On-device word vectors,
/// a table lookup, so it's quick on 5,000 items; Spotlight indexing waits for P12.
enum NearWords {
    static func records(for words: String, in index: SearchIndex, limit: Int = 8) -> [SearchDoc] {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return [] }
        let near = words.lowercased().split { !$0.isLetter }.map(String.init).flatMap { word -> [String] in
            guard embedding.contains(word) else { return [] }
            return index.vocabulary
                .map { ($0, embedding.distance(between: word, and: $0)) }
                .filter { $0.0 != word && $0.1 < 1.1 }   // cosine distance; past ~1.1 it's unrelated
                .sorted { $0.1 < $1.1 }
                .prefix(2)
                .map(\.0)
        }
        var seen = Set<UUID>()
        return Array(near.flatMap { index.records(matching: $0, limit: 4) }.filter { seen.insert($0.id).inserted }.prefix(limit))
    }
}
