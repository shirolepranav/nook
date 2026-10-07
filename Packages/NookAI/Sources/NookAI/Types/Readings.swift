import CoreGraphics
import Foundation
import ImageIO

// Shared result types (04 §2). P8's AI engine returns these same types, so screens can't
// tell which engine ran. Boxes are normalized 0–1 with a top-left origin, ready for SwiftUI.

/// One recognized line of text.
public struct TextLine: Sendable, Equatable {
    public var text: String
    public var box: CGRect
    public var confidence: Float
    /// Which page of a document it's on, from 0.
    public var page: Int
    /// How far down the page its middle is, with the photo's tilt taken out: lines side by
    /// side share a level even on a crooked receipt.
    public var level: CGFloat

    public init(text: String, box: CGRect = .zero, confidence: Float = 1, page: Int = 0, level: CGFloat? = nil) {
        (self.text, self.box, self.confidence, self.page) = (text, box, confidence, page)
        self.level = level ?? box.midY
    }
}

/// A photo to read: a sticker, a shelf.
public struct PhotoInput: Sendable {
    public let image: CGImage

    public init(image: CGImage) { self.image = image }

    /// Upright, at most `maxPixels` on the long edge.
    public init?(data: Data, maxPixels: Int = 3000) {
        guard let image = DocumentInput.image(from: data, maxPixels: maxPixels) else { return nil }
        self.image = image
    }
}

/// A receipt or document: one image per page.
public struct DocumentInput: Sendable {
    public let pages: [CGImage]

    public init(pages: [CGImage]) { self.pages = pages }

    public init?(imageData: Data) {
        guard let image = Self.image(from: imageData, maxPixels: 3000) else { return nil }
        pages = [image]
    }

    /// Renders a PDF's pages on white, like paper. Text PDFs go through the same reader,
    /// which also gives every number a box to highlight.
    /// ponytail: the first 5 pages only; long statements rarely keep the total further in.
    public init?(pdf url: URL, maxPages: Int = 5, pixels: CGFloat = 2000) {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else { return nil }
        pages = (1...min(document.numberOfPages, maxPages)).compactMap { number in
            guard let page = document.page(at: number) else { return nil }
            let box = page.getBoxRect(.mediaBox)
            let scale = pixels / max(box.width, box.height, 1)
            let width = Int(box.width * scale), height = Int(box.height * scale)
            guard width > 0, height > 0, let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return nil }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -box.minX, y: -box.minY)
            context.drawPDFPage(page)
            return context.makeImage()
        }
        if pages.isEmpty { return nil }
    }

    static func image(from data: Data, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // upright
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

/// What a receipt says (F4). Classic gives ranked candidates for the user to tap; it never
/// fills a field by itself (PRD §5).
public struct ReceiptReading: Sendable, Equatable {
    public struct Candidate<Value: Sendable & Equatable>: Sendable, Equatable {
        public var value: Value
        /// As printed, for the highlight's label.
        public var text: String
        public var page: Int
        public var box: CGRect
    }

    public var lines: [TextLine]
    /// Best first: a TOTAL line beats SUBTOTAL, which beats line items.
    public var amounts: [Candidate<Decimal>]
    /// Best first: a DATE line, then the first date on the receipt. None in the future.
    public var dates: [Candidate<Date>]
    public var store: String?
    public var currencyCode: String

    /// Every line, for search (Receipt.extractedText).
    public var text: String { lines.map(\.text).joined(separator: "\n") }
}

/// What a serial sticker says (F2). Lines are ranked: labeled serials, then models, then
/// anything that looks like a code.
public struct SerialReading: Sendable, Equatable {
    public struct Line: Sendable, Equatable {
        public enum Kind: Sendable, Equatable { case serial, model, code, other }
        /// As printed.
        public var text: String
        /// Without its label ("S/N: 7XK2" → "7XK2").
        public var value: String
        public var kind: Kind
        public var box: CGRect
    }

    public var lines: [Line]
    public var serial: String? { lines.first { $0.kind == .serial }?.value }

    public init(lines: [Line]) { self.lines = lines }
    public var model: String? { lines.first { $0.kind == .model }?.value }
}
