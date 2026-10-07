import Foundation

/// The Classic engine (04 §2): Vision text recognition and plain parsing, on every iPhone.
/// It returns candidates for the user to tap and never fills a field itself (PRD §5).
/// Until the router arrives in P8, the app calls `NookAI.classic` from one place per
/// capability (D48).
public struct ClassicEngine: Sendable {
    public init() {}

    /// Every page is read; candidates carry their page.
    public func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        var lines: [TextLine] = []
        for (page, image) in document.pages.enumerated() {
            lines += try await TextReader.lines(in: image, page: page)
        }
        return ReceiptParser.read(lines)
    }

    public func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        SerialParser.read(try await TextReader.lines(in: photo.image))
    }
}
