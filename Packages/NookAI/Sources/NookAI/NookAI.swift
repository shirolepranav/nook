import CoreGraphics
import Foundation
import NookKit

// NookAI: CapabilityRouter, AIEngine and ClassicEngine (04_Architecture.md §2). The app asks
// `NookAI.router` for every capability; it never picks an engine itself (D48, D53).
public enum NookAI {
    public static let appGroupID = NookKit.appGroupID

    public static let router: CapabilityRouter = {
        #if DEBUG
        // UI tests (D53): `-uiTestingFakeAI items` streams `ScriptedEngine.shelf`;
        // `-uiTestingFakeAI fail` throws at once, to exercise the silent fallback.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-uiTestingFakeAI"), flag + 1 < arguments.count {
            let fails = arguments[flag + 1] == "fail"
            return CapabilityRouter(ai: ScriptedEngine(items: fails ? nil : ScriptedEngine.shelf), classic: ClassicEngine()) {
                let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
                let off = defaults.object(forKey: CapabilityRouter.useAppleIntelligenceKey) as? Bool == false
                    || defaults.bool(forKey: CapabilityRouter.forceClassicKey)
                return off ? .classic : Availability(usesAI: true, seesImages: true)
            }
        }
        #endif
        return CapabilityRouter(ai: AIEngine(), classic: ClassicEngine())
    }()

    /// S-11's status. The scripted model reports Ready, so UI tests can reach the switch.
    public static var status: AIStatus {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingFakeAI") { return .ready(seesImages: true) }
        #endif
        return CapabilityRouter.systemStatus
    }
}

#if DEBUG
/// A stand-in model for UI tests and previews: the same items for every photo, a beat apart,
/// so streaming shows; or a failure, when `items` is nil.
public struct ScriptedEngine: CapabilityEngine {
    let items: [DetectedItem]?

    public init(items: [DetectedItem]?) { self.items = items }

    /// Six things for `CaptureFixtures.shelf`: three on its three blocks, three without a box.
    public static let shelf = [
        DetectedItem(name: "Kettle", category: "Appliances", condition: "good", box: CGRect(x: 0.08, y: 0.33, width: 0.24, height: 0.45)),
        DetectedItem(name: "Toaster", category: "Appliances", brand: "Breville", condition: "good",
                     box: CGRect(x: 0.38, y: 0.33, width: 0.24, height: 0.45)),
        DetectedItem(name: "Espresso machine", category: "Appliances", condition: "likeNew",
                     box: CGRect(x: 0.68, y: 0.33, width: 0.24, height: 0.45)),
        DetectedItem(name: "Stand mixer", category: "Appliances", condition: "good"),
        DetectedItem(name: "Blender", category: "Appliances", condition: "good"),
        DetectedItem(name: "Cookbook", category: "Kitchen"),
    ]

    struct Failure: Error {}

    public func detectItems(in photo: PhotoInput) -> AsyncThrowingStream<DetectedItem, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let items else { return continuation.finish(throwing: Failure()) }
                for item in items {
                    try? await Task.sleep(for: .milliseconds(150))
                    continuation.yield(item)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func fillItem(from photo: PhotoInput) async throws -> DetectedItem? {
        guard items != nil else { throw Failure() }
        return DetectedItem(name: "Kettle", category: "Appliances", brand: "Breville", condition: "likeNew")
    }

    /// The Classic reading, with its best candidates picked as a model would.
    public func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        guard items != nil else { throw Failure() }
        var reading = try await ClassicEngine().readReceipt(document)
        reading.suggested = .init(date: reading.dates.isEmpty ? nil : 0, amount: reading.amounts.isEmpty ? nil : 0,
                                  store: reading.store)
        return reading
    }

    public func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        guard items != nil else { throw Failure() }
        var reading = try await ClassicEngine().readSerial(from: photo)
        reading.isSuggested = reading.serial != nil
        return reading
    }

    /// "I put the passports in the safe" proposes a move (F-04); anything else reads the
    /// Classic way.
    public func understand(_ text: String, index: SearchIndex) async throws -> FindQuestion {
        guard items != nil else { throw Failure() }
        let lower = text.lowercased()
        guard lower.hasPrefix("i put "), let split = lower.range(of: " in ") else { return FindQuestion(text) }
        return FindQuestion(intent: .move, terms: FindQuestion(String(lower[..<split.lowerBound])).terms,
                            placeTerms: FindQuestion(String(lower[split.upperBound...])).terms)
    }

    public func estimateValue(for item: ValueSubject) async throws -> ValueEstimate? {
        guard items != nil else { throw Failure() }
        return ValueEstimate(low: 60, high: 90)
    }
}
#endif
