import CoreGraphics
import Foundation
import Synchronization
import Testing
@testable import NookAI

// The router contract (04 §2, ai-capability skill §5): the right engine per availability, and
// every AI failure falls back silently with the input untouched.

/// A fake engine: streams `items`, then throws or hangs when told to, and records the photo.
private final class FakeEngine: CapabilityEngine, @unchecked Sendable {
    enum Ending { case finish, fail, hang }

    let items: [DetectedItem]
    let ending: Ending
    let seen = Mutex<[Int]>([])   // widths of the photos it got

    init(_ items: [DetectedItem] = [], ending: Ending = .finish) { (self.items, self.ending) = (items, ending) }

    struct Failure: Error {}

    func detectItems(in photo: PhotoInput) -> AsyncThrowingStream<DetectedItem, Error> {
        seen.withLock { $0.append(photo.image.width) }
        return AsyncThrowingStream { continuation in
            let task = Task {
                for item in items { continuation.yield(item) }
                switch ending {
                case .finish: continuation.finish()
                case .fail: continuation.finish(throwing: Failure())
                case .hang: try? await Task.sleep(for: .seconds(60)); continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func fillItem(from photo: PhotoInput) async throws -> DetectedItem? {
        switch ending {
        case .finish: return items.first
        case .fail: throw Failure()
        case .hang: try await Task.sleep(for: .seconds(60)); return items.first
        }
    }

    func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        if ending == .fail { throw Failure() }
        return ReceiptReading(lines: [], amounts: [], dates: [], store: items.first?.name, currencyCode: "USD")
    }

    func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        if ending == .fail { throw Failure() }
        return SerialReading(lines: items.map { .init(text: $0.name, value: $0.name, kind: .serial, box: .zero) })
    }
}

private let kettle = DetectedItem(name: "Kettle", category: "Appliances")
private let toaster = DetectedItem(name: "Toaster", category: "Appliances")

private func photo(width: Int = 40) -> PhotoInput {
    let context = CGContext(data: nil, width: width, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return PhotoInput(image: context.makeImage()!)
}

private func collect(_ stream: AsyncStream<DetectedItem>) async -> [String] {
    var names: [String] = []
    for await item in stream { names.append(item.name) }
    return names
}

private let ai = Availability(usesAI: true, seesImages: true)

@Test func aiAvailabilityUsesTheAIEngine() async {
    let router = CapabilityRouter(ai: FakeEngine([kettle]), classic: FakeEngine([toaster])) { ai }
    #expect(await collect(router.detectItems(in: photo())) == ["Kettle"])
    #expect(router.detects)
}

@Test func classicAvailabilityUsesTheClassicEngine() async {
    let router = CapabilityRouter(ai: FakeEngine([kettle]), classic: FakeEngine([toaster])) { .classic }
    #expect(await collect(router.detectItems(in: photo())) == ["Toaster"])
    #expect(!router.detects)
}

// PRD §8 vision check: a model without image input keeps AI for text, never for photos.
@Test func aModelThatCantSeeImagesSendsPhotosToClassic() {
    let aiEngine = FakeEngine(), classicEngine = FakeEngine()
    let router = CapabilityRouter(ai: aiEngine, classic: classicEngine) { Availability(usesAI: true, seesImages: false) }
    #expect(router.engine(needsImages: true) as? FakeEngine === classicEngine)
    #expect(router.engine(needsImages: false) as? FakeEngine === aiEngine)
    #expect(!router.detects)
}

@Test func availabilityIsCheckedPerTask() async {
    let usesAI = Mutex(true)
    let router = CapabilityRouter(ai: FakeEngine([kettle]), classic: FakeEngine([toaster])) {
        usesAI.withLock { $0 } ? ai : .classic
    }
    #expect(await collect(router.detectItems(in: photo())) == ["Kettle"])
    usesAI.withLock { $0 = false }   // turned off mid-session
    #expect(await collect(router.detectItems(in: photo())) == ["Toaster"])
}

@Test func anAIFailureKeepsWhatArrivedAndEndsQuietly() async {
    let router = CapabilityRouter(ai: FakeEngine([kettle, toaster], ending: .fail), classic: FakeEngine()) { ai }
    #expect(await collect(router.detectItems(in: photo())) == ["Kettle", "Toaster"])
}

@Test func theTimeoutEndsAHungScanWithTheInputUntouched() async {
    let engine = FakeEngine([kettle], ending: .hang)
    let router = CapabilityRouter(ai: engine, classic: FakeEngine(), availability: { ai }, timeout: .milliseconds(100))
    let start = ContinuousClock.now
    #expect(await collect(router.detectItems(in: photo(width: 40))) == ["Kettle"])
    #expect(ContinuousClock.now - start < .seconds(5))
    #expect(engine.seen.withLock { $0 } == [40])
}

@Test func fillItemIsNilOnFailureTimeoutAndClassic() async {
    let failing = CapabilityRouter(ai: FakeEngine([kettle], ending: .fail), classic: ClassicEngine()) { ai }
    #expect(await failing.fillItem(from: photo()) == nil)
    let hung = CapabilityRouter(ai: FakeEngine([kettle], ending: .hang), classic: ClassicEngine(),
                                availability: { ai }, timeout: .milliseconds(100))
    #expect(await hung.fillItem(from: photo()) == nil)
    let classic = CapabilityRouter(ai: FakeEngine([kettle]), classic: ClassicEngine()) { .classic }
    #expect(await classic.fillItem(from: photo()) == nil)
    let working = CapabilityRouter(ai: FakeEngine([kettle]), classic: ClassicEngine()) { ai }
    #expect(await working.fillItem(from: photo())?.name == "Kettle")
}

@Test func aFailedAIReadFallsBackToClassic() async throws {
    let router = CapabilityRouter(ai: FakeEngine([kettle], ending: .fail), classic: FakeEngine([toaster])) { ai }
    #expect(try await router.readSerial(from: photo()).serial == "Toaster")
    #expect(try await router.readReceipt(DocumentInput(pages: [photo().image])).store == "Toaster")
}

// D53: a box is drawn only when the estimate is believable.
@Test func boxesAreCheckedBeforeTheyreDrawn() {
    #expect(close(DetectedItem(name: "Kettle", category: "", box: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)).box,
                  CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)))
    #expect(DetectedItem(name: "Kettle", category: "").box == nil)
    #expect(DetectedItem(name: "Kettle", category: "", box: CGRect(x: 0, y: 0, width: 1, height: 1)).box == nil)
    #expect(DetectedItem(name: "Kettle", category: "", box: CGRect(x: 0.5, y: 0.5, width: 0.01, height: 0.4)).box == nil)
    #expect(close(DetectedItem(name: "Kettle", category: "", box: CGRect(x: 0.8, y: 0.8, width: 0.5, height: 0.5)).box,
                  CGRect(x: 0.8, y: 0.8, width: 0.2, height: 0.2)))
}

private func close(_ a: CGRect?, _ b: CGRect) -> Bool {
    guard let a else { return false }
    return [a.minX - b.minX, a.minY - b.minY, a.width - b.width, a.height - b.height].allSatisfy { abs($0) < 1e-9 }
}

@Test func photosAreResizedToTheModelsSize() {
    #expect(photo(width: 3000).resized(maxPixels: 1536).image.width == 1536)
    #expect(photo(width: 40).resized(maxPixels: 1536).image.width == 40)
}
