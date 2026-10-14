import SwiftUI
import NookKit
import NookUI

/// Draws the insurance report, or an item's proof pack (D4), into a PDF on the device with
/// `ImageRenderer` (PRD §8), page by page so progress shows and Cancel stops it (R-02).
/// Budget: 500 items in under 20 s (F9).
@MainActor
struct ReportRenderer {
    let report: ReportSnapshot
    let cover: ReportCover
    var options = ReportOptions()
    var summaries: [UUID: String] = [:]
    var blobs = BlobStore.shared
    var size = ReportPaper.size

    var pages: [[ReportBlock]] { ReportLayout.pages(report, summaries: summaries, size: size) }

    /// Pages in the finished file: the report and, when asked, each receipt's pages.
    var pageCount: Int {
        pages.count + (options.receipts ? report.receipts.reduce(0) { $0 + receiptPages($1) } : 0)
    }

    /// The first page with a "PREVIEW" mark: what Free shows (PRD §7).
    func previewPage(thumbnails: [String: CGImage] = [:], watermarked: Bool) -> ReportPage {
        ReportPage(blocks: pages.first ?? [.cover], report: report, cover: cover, number: 1, count: pageCount,
                   options: options, thumbnails: thumbnails, watermarked: watermarked, size: size)
    }

    /// Writes the PDF to `url`. `progress` gets items drawn so far and the total.
    func render(to url: URL, progress: (Int, Int) -> Void = { _, _ in }) async throws {
        let pages = pages
        let thumbnails = options.photos ? await loadThumbnails() : [:]
        let total = report.itemCount
        let count = pageCount
        var box = CGRect(origin: .zero, size: size)
        guard let context = CGContext(url as CFURL, mediaBox: &box,
                                      [kCGPDFContextTitle: cover.title, kCGPDFContextCreator: "Nook"] as CFDictionary)
        else { throw CocoaError(.fileWriteUnknown) }
        var closed = false
        defer { if !closed { context.closePDF(); try? FileManager.default.removeItem(at: url) } }

        var drawn = 0
        for (index, blocks) in pages.enumerated() {
            try Task.checkCancellation()
            draw(ReportPage(blocks: blocks, report: report, cover: cover, number: index + 1, count: count,
                            options: options, thumbnails: thumbnails, size: size), in: context)
            drawn += blocks.filter { if case .line = $0 { true } else { false } }.count
            progress(drawn, total)
            await Task.yield()   // lets the progress bar and Cancel through
        }
        if options.receipts {
            var number = pages.count
            for receipt in report.receipts {
                try Task.checkCancellation()
                number = try await appendReceipt(receipt, from: number, of: count, in: context)
                await Task.yield()
            }
        }
        context.closePDF()
        closed = true
    }

    // MARK: Drawing

    private func draw(_ page: some View, in context: CGContext) {
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.render { _, draw in
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
        }
    }

    /// One page per image receipt; a PDF receipt keeps its own pages, each scaled under a caption.
    private func appendReceipt(_ receipt: ReportSnapshot.ReceiptFile, from number: Int, of count: Int,
                               in context: CGContext) async throws -> Int {
        let url = blobs.url(for: receipt.fileName, in: .receipts)
        var number = number
        if receipt.isPDF, let document = CGPDFDocument(url as CFURL) {
            for index in 1...max(document.numberOfPages, 1) {
                guard let page = document.page(at: index) else { continue }
                number += 1
                let caption = ReceiptPage(itemName: receipt.itemName, image: nil, number: number, count: count, size: size)
                let renderer = ImageRenderer(content: caption)
                renderer.proposedSize = ProposedViewSize(size)
                renderer.render { _, drawCaption in
                    context.beginPDFPage(nil)
                    drawCaption(context)
                    let frame = ReceiptPage.contentFrame(in: size)
                    context.saveGState()
                    // PDF space is flipped from SwiftUI's: place the page in the caption's box.
                    let flipped = CGRect(x: frame.minX, y: size.height - frame.maxY, width: frame.width, height: frame.height)
                    context.concatenate(page.getDrawingTransform(.mediaBox, rect: flipped, rotate: 0, preserveAspectRatio: true))
                    context.drawPDFPage(page)
                    context.restoreGState()
                    context.endPDFPage()
                }
            }
        } else {
            number += 1
            let image = await blobs.image(receipt.fileName, in: .receipts, maxPixels: 1600)
            draw(ReceiptPage(itemName: receipt.itemName, image: image, number: number, count: count, size: size), in: context)
        }
        return number
    }

    private func receiptPages(_ receipt: ReportSnapshot.ReceiptFile) -> Int {
        guard receipt.isPDF else { return 1 }
        return max(CGPDFDocument(blobs.url(for: receipt.fileName, in: .receipts) as CFURL)?.numberOfPages ?? 1, 1)
    }

    /// Thumbnails decode off the main actor, all at once (400 px, D7).
    func loadThumbnails(limit: Int = .max) async -> [String: CGImage] {
        let files = Set(report.sections.flatMap(\.lines).compactMap(\.photoFile).prefix(limit))
        let blobs = blobs
        return await withTaskGroup(of: (String, CGImage?).self) { group in
            for file in files { group.addTask { (file, await blobs.thumbnail(file)) } }
            var images: [String: CGImage] = [:]
            for await (file, image) in group { images[file] = image }
            return images
        }
    }
}

/// A receipt in the appendix: "Receipt · Espresso machine" over the receipt itself.
struct ReceiptPage: View {
    let itemName: String
    let image: CGImage?
    let number: Int
    let count: Int
    var size = ReportPaper.size

    static let captionHeight: CGFloat = 22 + NookSpace.s2

    static func contentFrame(in size: CGSize) -> CGRect {
        CGRect(x: ReportPaper.margin, y: ReportPaper.margin + captionHeight,
               width: size.width - 2 * ReportPaper.margin, height: ReportPaper.contentHeight(size) - captionHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Receipt · \(itemName)")
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .lineLimit(1)
                .frame(height: Self.captionHeight, alignment: .topLeading)
            Group {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Text("Page \(number) of \(count)")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textSecondary)
                .frame(height: ReportPaper.footerHeight, alignment: .bottomLeading)
        }
        .padding(ReportPaper.margin)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(image == nil ? Color.clear : NookColor.surfaceRaised)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
    }
}
