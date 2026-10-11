import CoreGraphics
import FoundationModels
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
