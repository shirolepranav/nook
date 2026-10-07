import CoreGraphics
import Foundation
import Vision

/// Vision text recognition (D49). Accurate mode with language correction off, so numbers and
/// codes come back as printed.
enum TextReader {
    static func lines(in image: CGImage, page: Int = 0) async throws -> [TextLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let observations = try await request.perform(on: image)
        let (width, height) = (CGFloat(image.width), CGFloat(image.height))
        // A photo of a receipt is rarely straight. The median tilt of the lines takes it out
        // of each line's `level`, so a label and its number far to the right share a row.
        let tilts = observations.map {
            atan2(($0.topRight.y - $0.topLeft.y) * height, ($0.topRight.x - $0.topLeft.x) * width)
        }.sorted()
        let tilt = tilts.isEmpty ? 0 : tilts[tilts.count / 2]
        return observations.compactMap { observation in
            guard let best = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox.cgRect   // lower-left origin
            let center = CGPoint(x: box.midX * width, y: box.midY * height)
            let level = 1 - (center.y * cos(tilt) - center.x * sin(tilt)) / height
            return TextLine(text: best.string,
                            box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height),
                            confidence: best.confidence, page: page, level: level)
        }
        .sorted { ($0.page, $0.level, $0.box.minX) < ($1.page, $1.level, $1.box.minX) }
    }
}
