import Foundation
import PDFKit
import SwiftData
import Testing
import UIKit
@testable import Nook
import NookKit

// F9 (P10): the insurance report's PDF. Pages are numbered, every item is on one, and 500
// items render inside the 20 s budget (PRD §9). The device timing is an owner check.

@MainActor
private func home(items count: Int, rooms: Int = 3, blobs: BlobStore) throws -> ModelContainer {
    let container = try NookStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let roomService = RoomService(context: context)
    let places = try (1...rooms).map { Location(room: try roomService.addRoom(named: "Room \($0)")) }
    let photos = try (0..<20).map { index in
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor(hue: CGFloat(index) / 20, saturation: 0.4, brightness: 0.9, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }
        return try blobs.savePhoto(image.pngData()!)
    }
    let items = ItemService(context: context, blobs: blobs, isPro: { true })   // not the shared Pro cache, which UI tests change
    for number in 1...count {
        var draft = ItemDraft(currencyCode: "USD", location: places[number % rooms])
        (draft.name, draft.price, draft.serial) = ("Thing \(number)", Decimal(number), "SN-\(number)")
        let photo = photos[number % photos.count]
        draft.photos = [.init(fileName: photo.fileName, width: photo.width, height: photo.height)]
        try items.create(draft)
    }
    try context.save()
    return container
}

@MainActor
private func renderer(_ container: ModelContainer, blobs: BlobStore) throws -> ReportRenderer {
    let report = try ReportSnapshot.make(ReportOptions(), context: container.mainContext, homeCurrency: "USD")
    return ReportRenderer(report: report, cover: ReportCover(title: "Maple Street · Home inventory", insurer: "Harbor Mutual",
                                                             policyNumber: "HM-22-4471", date: .now), blobs: blobs)
}

@MainActor @Test func everyItemIsOnANumberedPage() async throws {
    let blobs = BlobStore(root: .temporaryDirectory.appending(path: "ReportTests-\(UUID().uuidString)"))
    let container = try home(items: 60, blobs: blobs)
    let renderer = try renderer(container, blobs: blobs)
    let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
    try await renderer.render(to: url)
    let pdf = try #require(PDFDocument(url: url))
    #expect(pdf.pageCount == renderer.pageCount)   // the builder's count is the file's
    #expect(pdf.pageCount > 1)
    let pages = (0..<pdf.pageCount).map { pdf.page(at: $0)?.string ?? "" }
    #expect(pages[0].contains("Maple Street · Home inventory"))
    #expect(pages[0].contains("Harbor Mutual · Policy HM-22-4471"))
    for (index, text) in pages.enumerated() {
        #expect(text.contains("Page \(index + 1) of \(pdf.pageCount)"))
    }
    let all = pages.joined(separator: "\n")
    for number in 1...60 {
        #expect(all.contains("Thing \(number)\n") || all.contains("Thing \(number) "), "Thing \(number) is missing")
    }
    #expect(all.contains("SN-42"))
}

@MainActor @Test func cancellingStopsAndRemovesTheFile() async throws {
    let blobs = BlobStore(root: .temporaryDirectory.appending(path: "ReportTests-\(UUID().uuidString)"))
    let renderer = try renderer(try home(items: 200, blobs: blobs), blobs: blobs)
    let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
    let task = Task { try await renderer.render(to: url) { done, _ in if done > 20 { withUnsafeCurrentTask { $0?.cancel() } } } }
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

/// F9's budget: 500 items with photos in under 20 s. A simulator on a Mac is faster than an
/// iPhone 15; the device time is the owner's check (P10 QA).
@MainActor @Test func fiveHundredItemsRenderInBudget() async throws {
    let blobs = BlobStore(root: .temporaryDirectory.appending(path: "ReportTests-\(UUID().uuidString)"))
    let renderer = try renderer(try home(items: 500, rooms: 8, blobs: blobs), blobs: blobs)
    let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
    let time = try await ContinuousClock().measure { try await renderer.render(to: url) }
    print("REPORT 500 items · \(renderer.pageCount) pages · \(time)")
    #expect(time < .seconds(20))
}
