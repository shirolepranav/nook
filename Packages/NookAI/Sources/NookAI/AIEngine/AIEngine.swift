import CoreGraphics
import Foundation
import FoundationModels
import NookKit

/// The AI engine (04 §2): the on-device model, on Apple Intelligence iPhones. Only reached
/// through `CapabilityRouter`, which checks availability, the vision check and the timeout.
/// It suggests; it never writes (PRD §6).
struct AIEngine: CapabilityEngine {
    /// PRD §8 step 1: smaller photos keep the model fast.
    static let maxPixels = 1536

    private let classic = ClassicEngine()

    @Generable(description: "Everything worth cataloging in the photo")
    struct Scene {
        @Guide(description: "Each distinct item, the most prominent first", .maximumCount(20))
        var items: [DetectedItem]
    }

    static let instructions = """
        You help someone catalog the things they own from a photo of a room, shelf or cupboard.
        List each distinct object a person would want in a home inventory, with a short everyday \
        name. Give a brand only when its name or logo is clearly visible; use the tools to read \
        labels and barcodes. Ignore people, pets, walls, floors, reflections in mirrors and \
        pictures shown on screens. Estimate where each item is in the photo.
        """

    /// Items stream out as the model finishes each one, so the first card shows early (PRD §9).
    func detectItems(in photo: PhotoInput) -> AsyncThrowingStream<DetectedItem, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let image = photo.resized(maxPixels: Self.maxPixels).image
                    let session = LanguageModelSession(tools: [ReadLabels(image: image), ReadBarcodes(image: image)],
                                                       instructions: Self.instructions)
                    let stream = session.streamResponse(generating: Scene.self) {
                        "List the items in this photo."
                        Attachment(image)
                    }
                    var sent = 0
                    for try await snapshot in stream {
                        let items = (try? snapshot.rawContent.value([GeneratedContent].self, forProperty: "items")) ?? []
                        while sent < items.count, items[sent].isComplete {
                            if let item = try? DetectedItem(items[sent]), !item.name.isEmpty { continuation.yield(item) }
                            sent += 1
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func fillItem(from photo: PhotoInput) async throws -> DetectedItem? {
        let image = photo.resized(maxPixels: Self.maxPixels).image
        let session = LanguageModelSession(tools: [ReadLabels(image: image)], instructions: Self.instructions)
        let item = try await session.respond(generating: DetectedItem.self) {
            "Describe the main item in this photo."
            Attachment(image)
        }.content
        return item.name.isEmpty ? nil : item
    }

    /// Nothing the model said could be checked against the source: Classic takes over (D55).
    struct Ungrounded: Error {}

    // MARK: Receipts (F4)

    @Generable(description: "The purchase a receipt records")
    struct ReceiptFields {
        @Guide(description: "The shop's name as printed, usually at the top; empty if none")
        var store: String
        @Guide(description: "The purchase date as YYYY-MM-DD; empty if none")
        var date: String
        @Guide(description: "The total paid, tax included, as a plain number like 129.99; 0 if unclear")
        var total: Double
        @Guide(description: "The warranty length in months, only if the receipt states one; otherwise 0", .range(0...120))
        var warrantyMonths: Int
    }

    /// Reads the recognized text, then keeps only picks that match what's printed: a total
    /// and a date the Classic reader also found, a store named on a line, a warranty the text
    /// mentions. The model can point; it can't invent (D55).
    func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        var reading = try await classic.readReceipt(document)
        guard !reading.lines.isEmpty else { return reading }
        let session = LanguageModelSession(instructions: """
            You read shop receipts. Answer only from the receipt's text; leave a field empty or 0 \
            when the text doesn't say.
            """)
        let fields = try await session.respond(generating: ReceiptFields.self) {
            "Read this receipt:"
            Self.excerpt(reading.lines.map(\.text))
        }.content

        let text = reading.text.lowercased()
        var suggested = ReceiptReading.Suggested()
        suggested.amount = reading.amounts.firstIndex { abs(($0.value as NSDecimalNumber).doubleValue - fields.total) < 0.005 }
        if let date = Self.isoDay.date(from: fields.date) {
            suggested.date = reading.dates.firstIndex { Calendar.current.isDate($0.value, inSameDayAs: date) }
        }
        let store = fields.store.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.count > 1, text.contains(store.lowercased()) { suggested.store = store }
        if Self.mentionsWarranty(of: fields.warrantyMonths, in: text) { suggested.warrantyMonths = fields.warrantyMonths }
        guard !suggested.isEmpty else { throw Ungrounded() }
        reading.suggested = suggested
        return reading
    }

    /// "2 YEAR WARRANTY", "24 month guarantee": the length has to be printed near the word.
    static func mentionsWarranty(of months: Int, in text: String) -> Bool {
        guard months > 0, text.contains("warrant") || text.contains("guarantee") else { return false }
        var numbers = ["\(months)"]
        if months % 12 == 0 { numbers.append("\(months / 12)") }
        return numbers.contains { text.range(of: "\\b\($0)[ -]?(yr|year|month|mo)", options: .regularExpression) != nil }
    }

    /// The model reads a few thousand words at most. ponytail: a very long receipt keeps its
    /// head (the store, the date) and tail (the total); the middle's line items go.
    static func excerpt(_ lines: [String], keep: Int = 50) -> String {
        guard lines.count > keep * 2 else { return lines.joined(separator: "\n") }
        return (lines.prefix(keep) + ["…"] + lines.suffix(keep)).joined(separator: "\n")
    }

    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: Serials (F2)

    @Generable(description: "Which lines of a product sticker hold its numbers")
    struct SerialLabels {
        @Guide(description: "The number of the line with the serial number, or -1")
        var serialLine: Int
        @Guide(description: "The number of the line with the model number, or -1")
        var modelLine: Int
    }

    /// The model labels lines the reader found, so a serial is always one printed on the
    /// sticker (D55). The labeled lines go first, as C-08 lists them.
    func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        var reading = try await classic.readSerial(from: photo)
        guard !reading.lines.isEmpty else { return reading }
        let session = LanguageModelSession(instructions: """
            You read the label on the back or bottom of a product. Serial numbers are often marked \
            S/N or SER; model numbers MODEL, MOD or M/N.
            """)
        let numbered = reading.lines.enumerated().map { "\($0.offset): \($0.element.text)" }.joined(separator: "\n")
        let labels = try await session.respond(generating: SerialLabels.self) {
            "Which line is the serial number, and which the model number?"
            numbered
        }.content

        let range = reading.lines.indices
        let serial = range.contains(labels.serialLine) ? labels.serialLine : nil
        let model = range.contains(labels.modelLine) && labels.modelLine != serial ? labels.modelLine : nil
        guard serial != nil || model != nil else { throw Ungrounded() }
        var lines = reading.lines
        for (index, line) in lines.enumerated() where line.kind == .serial || line.kind == .model {
            lines[index].kind = .code   // the model's labels replace the reader's
        }
        if let serial { lines[serial].kind = .serial }
        if let model { lines[model].kind = .model }
        let order: (SerialReading.Line.Kind) -> Int = { [.serial: 0, .model: 1][$0] ?? 2 }
        reading.lines = lines.enumerated()
            .sorted { (order($0.element.kind), $0.offset) < (order($1.element.kind), $1.offset) }
            .map(\.element)
        reading.isSuggested = true
        return reading
    }

    // MARK: "Where is…?" (PRD §6)

    @Generable(description: "What someone typed into the search of their home inventory")
    struct ParsedQuestion {
        @Guide(description: """
            locate: where something is. who: who borrowed it. contents: what's in a room, spot or box. \
            quantity: whether they have any, or how many. move: they say where they just put something.
            """, .anyOf(["locate", "who", "contents", "quantity", "move"]))
        var intent: String
        @Guide(description: "The thing, in the words lookUp found; just the shared word when several match and they didn't say which; empty for contents")
        var item: String
        @Guide(description: "The room, spot or box they named, in the words lookUp found; empty if none")
        var place: String
    }

    static let findInstructions = """
        You turn what someone types about their belongings into a search. Use lookUp to find how \
        their things and places are named, and answer with those names. Never guess a location: \
        you only choose words; the app finds the answer in its records.
        """

    /// The model only picks the words; Find builds the answer from records (D55). Words that
    /// find nothing saved are thrown back, so the Classic reading answers instead.
    func understand(_ text: String, index: SearchIndex) async throws -> FindQuestion {
        let session = LanguageModelSession(tools: [LookUp(index: index)], instructions: Self.findInstructions)
        let parsed = try await session.respond(generating: ParsedQuestion.self) {
            "They typed: \(text)"
        }.content

        let terms = FindQuestion(parsed.item).terms, placeTerms = FindQuestion(parsed.place).terms
        let placeFound = !placeTerms.isEmpty && index.records(matching: parsed.place).contains { $0.kind != .item }
        switch parsed.intent {
        case "contents":
            guard placeFound else { throw Ungrounded() }
            return FindQuestion(intent: .contents, terms: placeTerms)
        case "move":
            guard placeFound, !terms.isEmpty, !index.records(matching: parsed.item).isEmpty else { throw Ungrounded() }
            return FindQuestion(intent: .move, terms: terms, placeTerms: placeTerms)
        default:
            guard !terms.isEmpty, !index.records(matching: parsed.item).isEmpty else { throw Ungrounded() }
            let intent: FindQuestion.Intent = switch parsed.intent {
            case "who": .who
            case "quantity": .quantity
            default: .locate
            }
            return FindQuestion(intent: intent, terms: terms)
        }
    }

    // MARK: Value (D16)

    @Generable(description: "What replacing an item would cost today")
    struct ValueRange {
        @Guide(description: "The low end, in whole units of the given currency; 0 if you can't tell")
        var low: Double
        @Guide(description: "The high end, in whole units of the given currency; 0 if you can't tell")
        var high: Double
    }

    func estimateValue(for item: ValueSubject) async throws -> ValueEstimate? {
        let session = LanguageModelSession(instructions: """
            You estimate what it would cost to replace a household item today with a comparable one, \
            new or second-hand as fits its condition. Give a realistic range. If you can't tell, give 0.
            """)
        var facts = ["Item: \(item.name)"]
        if !item.category.isEmpty { facts.append("Category: \(item.category)") }
        if let brand = item.brand, !brand.isEmpty { facts.append("Brand: \(brand)") }
        if let condition = item.condition { facts.append("Condition: \(condition)") }
        if let price = item.price { facts.append("Bought for: \(price) \(item.currencyCode)") }
        if let date = item.purchaseDate { facts.append("Bought: \(Self.isoDay.string(from: date))") }
        let range = try await session.respond(generating: ValueRange.self) {
            "Currency: \(item.currencyCode)"
            facts.joined(separator: "\n")
        }.content
        return ValueEstimate(low: range.low, high: range.high)
    }
}
