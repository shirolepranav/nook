import Foundation

/// The Classic engine (04 §2): Vision text recognition and plain parsing, on every iPhone.
/// It returns candidates for the user to tap and never fills a field itself (PRD §5), so it
/// finds no items in a room scan: the user tags them (C-04).
public struct ClassicEngine: CapabilityEngine {
    public init() {}

    public func detectItems(in photo: PhotoInput) -> AsyncThrowingStream<DetectedItem, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    public func fillItem(from photo: PhotoInput) async throws -> DetectedItem? { nil }

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
