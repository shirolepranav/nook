import Foundation
import FoundationModels
import NookKit
import os

/// One task the app can ask for. Each has an AI and a Classic implementation that return the
/// same types, so screens can't tell which engine ran (04 §2).
public protocol CapabilityEngine: Sendable {
    /// F3. Classic finds nothing: the user tags (C-04).
    func detectItems(in photo: PhotoInput) -> AsyncThrowingStream<DetectedItem, Error>
    /// C-05's prefill. Classic leaves the fields to the user.
    func fillItem(from photo: PhotoInput) async throws -> DetectedItem?
    func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading
    func readSerial(from photo: PhotoInput) async throws -> SerialReading
}

/// What the on-device model can do right now.
public struct Availability: Sendable, Equatable {
    public var usesAI: Bool
    /// Some Apple Intelligence models can't take images (PRD §8 vision check, D54): photos then
    /// take the Classic path while text questions keep AI.
    public var seesImages: Bool

    public init(usesAI: Bool, seesImages: Bool) {
        (self.usesAI, self.seesImages) = (usesAI, seesImages)
    }

    public static let classic = Availability(usesAI: false, seesImages: false)
}

/// S-11's status line.
public enum AIStatus: Sendable, Equatable {
    case ready(seesImages: Bool), downloading, unavailable, off
}

/// Picks the engine per task (04 §2). Services and screens ask it; nothing else touches an
/// engine or Foundation Models. AI failures never surface: the Classic result, or no result,
/// stands in silently.
public struct CapabilityRouter: Sendable {
    /// S-11's "Use Apple Intelligence", in the App Group's defaults. On unless turned off.
    public static let useAppleIntelligenceKey = "useAppleIntelligence"
    /// Debug builds' "Force classic engine" (05 §6). `-forceClassicEngine YES` sets it too.
    public static let forceClassicKey = "forceClassicEngine"
    /// PRD §8: 20 s per photo or request, then the manual path.
    public static let timeout = Duration.seconds(20)

    let ai: any CapabilityEngine
    let classic: any CapabilityEngine
    let availability: @Sendable () -> Availability
    let timeout: Duration

    public init(ai: any CapabilityEngine, classic: any CapabilityEngine,
                availability: @escaping @Sendable () -> Availability = CapabilityRouter.systemAvailability,
                timeout: Duration = CapabilityRouter.timeout) {
        (self.ai, self.classic, self.availability, self.timeout) = (ai, classic, availability, timeout)
    }

    /// Checked per task, never cached: the user can turn AI off, or the model can finish
    /// downloading, mid-session.
    public func engine(needsImages: Bool) -> any CapabilityEngine {
        let now = availability()
        return now.usesAI && (now.seesImages || !needsImages) ? ai : classic
    }

    /// True when a photo would go to the model, so C-03 can show "Looking for items…".
    public var detects: Bool { let now = availability(); return now.usesAI && now.seesImages }

    // MARK: Tasks

    /// Room scan (F3). Items stream in as they're found. A failure or the 20 s timeout ends the
    /// stream quietly, keeping what already arrived; the screen's manual tools cover the rest
    /// of that photo (PRD §8 step 5).
    public func detectItems(in photo: PhotoInput) -> AsyncStream<DetectedItem> {
        let engine = engine(needsImages: true)
        let timeout = timeout
        return AsyncStream { continuation in
            let task = Task {
                let scan = Self.signposter.beginInterval("photoScan")
                defer { Self.signposter.endInterval("photoScan", scan) }
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        var first = true
                        do {
                            for try await item in engine.detectItems(in: photo) {
                                if first { Self.signposter.emitEvent("firstItem"); first = false }
                                continuation.yield(item)
                            }
                        } catch {
                            Self.log.info("Room scan fell back: \(String(describing: type(of: error)), privacy: .public)")
                        }
                    }
                    group.addTask { try? await Task.sleep(for: timeout) }
                    await group.next()
                    group.cancelAll()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Quick add's prefill (C-05), or nil: Classic, a failure or the timeout leave the form
    /// as the user would find it anyway.
    public func fillItem(from photo: PhotoInput) async -> DetectedItem? {
        let engine = engine(needsImages: true)
        return await withTaskGroup(of: DetectedItem??.self) { group in
            group.addTask { try? await engine.fillItem(from: photo) }
            group.addTask { try? await Task.sleep(for: self.timeout); return .some(nil) }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }

    /// Receipts (F4). Either engine's reading; a failed AI read falls back to Classic.
    public func readReceipt(_ document: DocumentInput) async throws -> ReceiptReading {
        let engine = engine(needsImages: true)
        guard engine is ClassicEngine == false, let reading = try? await engine.readReceipt(document) else {
            return try await classic.readReceipt(document)
        }
        return reading
    }

    /// Serial stickers (F2). A failed AI read falls back to Classic.
    public func readSerial(from photo: PhotoInput) async throws -> SerialReading {
        let engine = engine(needsImages: true)
        guard engine is ClassicEngine == false, let reading = try? await engine.readSerial(from: photo) else {
            return try await classic.readSerial(from: photo)
        }
        return reading
    }

    // MARK: The system

    public static let systemAvailability: @Sendable () -> Availability = {
        let defaults = UserDefaults(suiteName: NookKit.appGroupID) ?? .standard
        let off = defaults.object(forKey: useAppleIntelligenceKey) as? Bool == false
        let forced = defaults.bool(forKey: forceClassicKey) || UserDefaults.standard.bool(forKey: forceClassicKey)
        let model = SystemLanguageModel.default
        guard !off, !forced, model.availability == .available else { return .classic }
        return Availability(usesAI: true, seesImages: model.capabilities.contains(.vision))
    }

    /// S-11. Reports the system, not the app's toggle, which S-11 shows beside it.
    public static var systemStatus: AIStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available: return .ready(seesImages: model.capabilities.contains(.vision))
        case .unavailable(.modelNotReady): return .downloading
        case .unavailable(.appleIntelligenceNotEnabled): return .off
        default: return .unavailable
        }
    }

    // Never logs user content (CLAUDE.md): only that a fallback happened, and why in type terms.
    static let log = Logger(subsystem: "pranav.nook", category: "router")
    /// PRD §9 budgets: first item under 2 s, a one-photo scan under 8 s.
    static let signposter = OSSignposter(subsystem: "pranav.nook", category: .pointsOfInterest)
}
