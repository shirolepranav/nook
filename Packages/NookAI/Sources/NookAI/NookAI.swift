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

    public func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        try await ClassicEngine().readReceipt(document)
    }

    public func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        try await ClassicEngine().readSerial(from: photo)
    }
}
#endif
