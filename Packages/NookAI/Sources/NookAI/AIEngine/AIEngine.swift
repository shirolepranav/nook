import CoreGraphics
import FoundationModels

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

    // P9 brings AI receipts and serials; until then both read the Classic way.
    func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        try await classic.readReceipt(document)
    }

    func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        try await classic.readSerial(from: photo)
    }
}
