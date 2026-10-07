#!/usr/bin/env swift
// Renders the synthetic receipt fixtures for ReceiptFixtureTests (P6, D48): Fixtures/receipts/
// clean/ (the bar is 100%) and hard/ (rotated, faded, noisy; at least 80%), each image with an
// <name>.json of what it should read. Also Fixtures/serials/. Real photos go in
// Fixtures/receipts/real/ with their own JSON and are picked up by the same test.
// Run from the repo root: swift scripts/make-receipt-fixtures.swift
import AppKit
import CoreImage

struct Receipt {
    let name: String
    let lines: [String]
    let total: String
    let date: String        // yyyy-MM-dd
    let currency: String
    var pages: [[String]]? = nil   // a multi-page PDF instead of an image
}

let item = { (name: String, price: String) in name.padding(toLength: 24, withPad: " ", startingAt: 0) + price }

let receipts: [Receipt] = [
    Receipt(name: "us-home-goods", lines: [
        "HOME GOODS CO.", "412 Maple Ave", "Springfield, IL", "", "09/14/2026  14:32", "",
        item("ESPRESSO MCH EM-4200", "649.00"), item("2-YR PROTECTION", "59.00"), "",
        item("SUBTOTAL", "708.00"), item("TAX 8.25%", "58.41"), item("TOTAL", "$766.41"),
        item("CASH", "800.00"), item("CHANGE", "33.59"), "", "THANK YOU",
    ], total: "766.41", date: "2026-09-14", currency: "USD"),
    Receipt(name: "de-elektro", lines: [
        "Elektro Markt Berlin", "Kantstr. 12", "", "Datum: 23.08.2026 11:05", "",
        item("Waschmaschine WM-7", "1.299,00"), item("Lieferung", "49,50"), "",
        item("SUMME EUR", "1.348,50"), item("MwSt 19%", "215,31"), "", "Vielen Dank",
    ], total: "1348.50", date: "2026-08-23", currency: "EUR"),
    Receipt(name: "uk-garden", lines: [
        "Greenleaf Garden Centre", "High Street, Bath", "", "17/07/2026", "",
        item("Rose bush x2", "£24.98"), item("Compost 50L", "£9.99"), item("Hedge trimmer", "£49.99"), "",
        item("TOTAL", "£84.96"), item("CARD", "£84.96"), "",
    ], total: "84.96", date: "2026-07-17", currency: "GBP"),
    Receipt(name: "jp-denki", lines: [
        "Sakura Denki Tokyo", "", "2026-06-21 18:40", "",
        item("Rice cooker", "¥12,800"), item("Tax", "¥1,280"), "",
        item("TOTAL", "¥14,080"), "",
    ], total: "14080", date: "2026-06-21", currency: "JPY"),
    Receipt(name: "in-electronics", lines: [
        "Croma Electronics", "Bandra West, Mumbai", "", "Date: 14 Sep 2026", "",
        item("Smart TV 55in", "Rs. 45,999.00"), item("Wall mount", "Rs. 1,499.00"), "",
        item("GRAND TOTAL", "Rs. 47,498.00"), "",
        // Thermal printers print "Rs."; a printed ₹ is often read as a 7 or a 2 (D48).
    ], total: "47498.00", date: "2026-09-14", currency: "INR"),
    Receipt(name: "us-text-month", lines: [
        "Corner Hardware", "", "Sep 3, 2026", "",
    ] + (1...24).map { item("Item \($0) hex bolt pack", String(format: "%d.%02d", $0, ($0 * 7) % 100)) } + [
        "", item("SUBTOTAL", "311.00"), item("SALES TAX", "25.66"), item("TOTAL", "336.66"), "",
    ], total: "336.66", date: "2026-09-03", currency: "USD"),
    Receipt(name: "fr-maison", lines: [
        "Maison & Jardin", "Lyon", "", "14/08/2026", "",
        item("Lampe de bureau", "39,90 €"), item("Ampoules x4", "12,00 €"), item("Vase", "38,00 €"), "",
        item("TOTAL TTC", "89,90 €"), item("TVA 20%", "14,98 €"), "",
    ], total: "89.90", date: "2026-08-14", currency: "EUR"),
    Receipt(name: "us-iso-date", lines: [
        "Bright Bikes", "", "2026-04-02", "",
        item("Commuter bike", "899.99"), item("Helmet", "64.00"), item("Lock", "45.00"), "",
        item("AMOUNT DUE", "1,008.99"), "",
    ], total: "1008.99", date: "2026-04-02", currency: "USD"),
    Receipt(name: "uk-text-month", lines: [
        "Book Nook Ltd", "", "28 March 2026", "",
        item("Hardback", "£18.99"), item("Bookmark", "£2.50"), "",
        item("Total", "£21.49"), "",
    ], total: "21.49", date: "2026-03-28", currency: "GBP"),
    Receipt(name: "us-short-year", lines: [
        "Daily Grocer", "", "11/30/25  09:12", "",
        item("Coffee beans", "14.99"), item("Milk", "3.49"), "",
        item("TOTAL", "18.48"), item("VISA", "18.48"), "",
    ], total: "18.48", date: "2025-11-30", currency: "USD"),
    Receipt(name: "de-dash-date", lines: [
        "Moebel Haus", "", "Kaufdatum 19-01-2026", "",
        item("Sofa Lina", "2.450,00"), item("Kissen x2", "39,80"), "",
        item("GESAMT", "2.489,80 EUR"), "",
    ], total: "2489.80", date: "2026-01-19", currency: "EUR"),
    Receipt(name: "us-two-page", lines: [], total: "1336.23", date: "2026-05-30", currency: "USD", pages: [
        ["Camera World", "", "2026-05-30", ""] + (1...14).map { item("Lens filter \($0)", "\(40 + $0).00") },
        (15...24).map { item("Lens filter \($0)", "\(40 + $0).00") } + [
            "", item("SUBTOTAL", "1,260.00"), item("TAX", "76.23"), item("TOTAL", "1,336.23"), "", "Thank you",
        ],
    ]),
]

let root = URL(filePath: FileManager.default.currentDirectoryPath).appending(path: "Fixtures")
let font = NSFont(name: "Menlo", size: 22)!

func render(_ lines: [String]) -> CGImage {
    let lineHeight: CGFloat = 32, width = 640
    let height = Int(CGFloat(lines.count) * lineHeight + 80)
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 0.98, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    for (index, line) in lines.enumerated() {
        let y = CGFloat(height) - 40 - CGFloat(index + 1) * lineHeight
        (line as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: font, .foregroundColor: NSColor.black])
    }
    return context.makeImage()!
}

let ci = CIContext()
func hard(_ image: CGImage, _ kind: String) -> CGImage {
    var output = CIImage(cgImage: image)
    switch kind {
    case "rotated":
        output = output.transformed(by: CGAffineTransform(rotationAngle: 0.07))
            .composited(over: CIImage(color: CIColor(red: 0.55, green: 0.5, blue: 0.45)).cropped(to: output.extent.insetBy(dx: -60, dy: -60)))
    case "faded":
        output = output.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.35, kCIInputBrightnessKey: 0.25])
    default:   // noisy and slightly soft, like a phone photo in a dim room
        let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!.cropped(to: output.extent)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 0.3])
        output = output.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8]).cropped(to: output.extent)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: noise.applyingFilter(
                "CIColorClamp", parameters: ["inputMinComponents": CIVector(x: 0.8, y: 0.8, z: 0.8, w: 1)])])
    }
    return ci.createCGImage(output, from: output.extent)!
}

func writeJPEG(_ image: CGImage, to url: URL) {
    let data = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
    try! data.write(to: url)
}

func writePDF(_ pages: [CGImage], to url: URL) {
    var box = CGRect(x: 0, y: 0, width: 320, height: 0)
    let consumer = CGDataConsumer(url: url as CFURL)!
    let pdf = CGContext(consumer: consumer, mediaBox: &box, nil)!
    for page in pages {
        var media = CGRect(x: 0, y: 0, width: 320, height: CGFloat(page.height) / 2)
        pdf.beginPage(mediaBox: &media)
        pdf.draw(page, in: media)
        pdf.endPage()
    }
    pdf.closePDF()
}

func writeJSON(_ receipt: Receipt, to url: URL) {
    let json = ["total": receipt.total, "date": receipt.date, "currency": receipt.currency]
    try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}

for folder in ["receipts/clean", "receipts/hard", "receipts/real", "serials"] {
    try FileManager.default.createDirectory(at: root.appending(path: folder), withIntermediateDirectories: true)
}
for receipt in receipts {
    let clean = root.appending(path: "receipts/clean")
    if let pages = receipt.pages {
        writePDF(pages.map(render), to: clean.appending(path: receipt.name + ".pdf"))
    } else {
        let image = render(receipt.lines)
        writeJPEG(image, to: clean.appending(path: receipt.name + ".jpg"))
        // The hard set: every third receipt in each damage.
        for (offset, kind) in ["rotated", "faded", "noisy"].enumerated() {
            guard let index = receipts.firstIndex(where: { $0.name == receipt.name }),
                  index % 3 == offset || index < 5 else { continue }
            writeJPEG(hard(image, kind), to: root.appending(path: "receipts/hard/\(receipt.name)-\(kind).jpg"))
            writeJSON(receipt, to: root.appending(path: "receipts/hard/\(receipt.name)-\(kind).json"))
        }
    }
    writeJSON(receipt, to: clean.appending(path: receipt.name + ".json"))
}

// A serial sticker (C-08).
let sticker = render(["BREWMASTER", "MODEL: EM-4200", "S/N: 7XK2-48812-QA", "MFD 2025-03", "120V ~ 60Hz 1350W"])
writeJPEG(sticker, to: root.appending(path: "serials/brewmaster.jpg"))
try JSONSerialization.data(withJSONObject: ["serial": "7XK2-48812-QA", "model": "EM-4200"], options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appending(path: "serials/brewmaster.json"))
print("Wrote fixtures to \(root.path)")
