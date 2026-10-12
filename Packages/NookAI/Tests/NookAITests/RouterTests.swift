import CoreGraphics
import Foundation
import NaturalLanguage
import NookKit
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
        if ending == .hang { try await Task.sleep(for: .seconds(60)) }
        return SerialReading(lines: items.map { .init(text: $0.name, value: $0.name, kind: .serial, box: .zero) })
    }

    /// Reads every question as the first item's name, so tests can tell the engines apart.
    func understand(_ text: String, index: SearchIndex) async throws -> FindQuestion {
        switch ending {
        case .finish: return FindQuestion(intent: .locate, terms: items.map { $0.name.lowercased() })
        case .fail: throw Failure()
        case .hang: try await Task.sleep(for: .seconds(60)); return FindQuestion(text)
        }
    }

    func estimateValue(for item: ValueSubject) async throws -> ValueEstimate? {
        switch ending {
        case .finish: return ValueEstimate(low: 40, high: 60)
        case .fail: throw Failure()
        case .hang: try await Task.sleep(for: .seconds(60)); return nil
        }
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

// P9: text tasks keep AI on a model that can't see images (PRD §8 vision check).
@Test func aModelThatCantSeeImagesStillReadsTextTasks() async throws {
    let router = CapabilityRouter(ai: FakeEngine([kettle]), classic: FakeEngine([toaster])) {
        Availability(usesAI: true, seesImages: false)
    }
    #expect(try await router.readSerial(from: photo()).serial == "Kettle")
    #expect(try await router.readReceipt(DocumentInput(pages: [photo().image])).store == "Kettle")
    #expect(await router.understand("kettle?", index: .empty).terms == ["kettle"])
    #expect(await router.estimateValue(for: ValueSubject(name: "Kettle", currencyCode: "USD")) != nil)
}

@Test func questionsFallBackToTheClassicReading() async {
    let working = CapabilityRouter(ai: FakeEngine([kettle]), classic: FakeEngine([toaster])) { ai }
    #expect(await working.understand("where", index: .empty).terms == ["kettle"])
    let classic = CapabilityRouter(ai: FakeEngine([kettle]), classic: FakeEngine([toaster])) { .classic }
    #expect(await classic.understand("where", index: .empty).terms == ["toaster"])
    let failing = CapabilityRouter(ai: FakeEngine([kettle], ending: .fail), classic: ClassicEngine()) { ai }
    #expect(await failing.understand("I put the passports in the safe", index: .empty)
            == FindQuestion("I put the passports in the safe"))                 // a search, never a move
    let hung = CapabilityRouter(ai: FakeEngine([kettle], ending: .hang), classic: ClassicEngine(),
                                availability: { ai }, timeout: .milliseconds(100))
    #expect(await hung.understand("Where are the passports?", index: .empty).terms == ["passports"])
}

@Test func aSlowAIReadFallsBackToClassicToo() async throws {
    let router = CapabilityRouter(ai: FakeEngine([kettle], ending: .hang), classic: FakeEngine([toaster]),
                                  availability: { ai }, timeout: .milliseconds(100))
    let start = ContinuousClock.now
    #expect(try await router.readSerial(from: photo()).serial == "Toaster")
    #expect(ContinuousClock.now - start < .seconds(5))
}

@Test func valueEstimatesAreAIOnlyAndNeverFail() async {
    let subject = ValueSubject(name: "Kettle", currencyCode: "USD")
    let working = CapabilityRouter(ai: FakeEngine(), classic: FakeEngine()) { ai }
    #expect(await working.estimateValue(for: subject) == ValueEstimate(low: 40, high: 60))
    #expect(await CapabilityRouter(ai: FakeEngine(), classic: FakeEngine()) { .classic }.estimateValue(for: subject) == nil)
    #expect(await CapabilityRouter(ai: FakeEngine(ending: .fail), classic: FakeEngine()) { ai }.estimateValue(for: subject) == nil)
    let hung = CapabilityRouter(ai: FakeEngine(ending: .hang), classic: FakeEngine(), availability: { ai }, timeout: .milliseconds(100))
    #expect(await hung.estimateValue(for: subject) == nil)
}

// D55: a range is shown only when it's believable.
@Test func valueRangesAreChecked() {
    #expect(ValueEstimate(low: 419.6, high: 510.2).map { [$0.low, $0.high] } == [420, 510])
    #expect(ValueEstimate(low: 0, high: 0) == nil)
    #expect(ValueEstimate(low: 500, high: 400) == nil)
    #expect(ValueEstimate(low: 10, high: 5000) == nil)
    #expect(ValueEstimate(low: .nan, high: 10) == nil)
}

// D55: the model's picks must be printed on the receipt.
@Test func aWarrantyCountsOnlyWhenTheReceiptSaysSo() {
    #expect(AIEngine.mentionsWarranty(of: 24, in: "2 year warranty included"))
    #expect(AIEngine.mentionsWarranty(of: 24, in: "24-month guarantee"))
    #expect(!AIEngine.mentionsWarranty(of: 24, in: "warranty available at extra cost"))
    #expect(!AIEngine.mentionsWarranty(of: 12, in: "1 year subscription"))
    #expect(!AIEngine.mentionsWarranty(of: 0, in: "0 year warranty"))
}

@Test func aVeryLongReceiptKeepsItsHeadAndTail() {
    let lines = (1...300).map { "line \($0)" }
    let excerpt = AIEngine.excerpt(lines).split(separator: "\n")
    #expect(excerpt.count == 101 && excerpt.first == "line 1" && excerpt.last == "line 300")
    #expect(AIEngine.excerpt(["a", "b"]) == "a\nb")
}

// D55: loose wording finds saved words by meaning, never a Private item.
@Test func nearWordsFindLooseWording() throws {
    let index = SearchIndex(docs: [
        SearchDoc(id: UUID(), kind: .item, name: "TV remote"),
        SearchDoc(id: UUID(), kind: .item, name: "Duvet"),
        SearchDoc(id: UUID(), kind: .item, name: "Passport", isPrivate: true),
    ])
    try #require(NLEmbedding.wordEmbedding(for: .english) != nil)   // the asset can be missing
    #expect(NearWords.records(for: "clicker", in: index).map(\.name) == ["TV remote"])
    #expect(NearWords.records(for: "comforter", in: index).map(\.name) == ["Duvet"])
    #expect(NearWords.records(for: "zzzz", in: index).isEmpty)
}
