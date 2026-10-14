import SwiftUI
import LocalAuthentication
import NookKit

/// S-05's "Lock after" (D28).
enum LockTiming: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .immediately: "Right away"
        case .oneMinute: "1 min"
        case .fiveMinutes: "5 min"
        }
    }
}

/// The Face ID / Touch ID app lock (L-02, S-05) and the Private-item lock (PRD §9, F11).
/// One unlock opens Nook and every Private item until Nook leaves the screen, or, with the
/// app lock on, until the lock's timer runs out (D61). This is the only place that asks
/// `LocalAuthentication`.
@Observable @MainActor
final class AppLock {
    /// What unlocks this device, for copy only ("Unlock with Touch ID"). A capability, not
    /// a device check (CLAUDE.md: size classes only).
    enum Method: Equatable {
        case faceID, touchID, opticID, passcode
        /// No passcode is set, so nothing can be locked (S-05's unavailable state).
        case unavailable

        var name: String {
            switch self {
            case .faceID: String(localized: "Face ID")
            case .touchID: String(localized: "Touch ID")
            case .opticID: String(localized: "Optic ID")
            case .passcode, .unavailable: String(localized: "Passcode")
            }
        }

        var symbol: String {
            switch self {
            case .faceID: "faceid"
            case .touchID: "touchid"
            case .opticID: "opticid"
            case .passcode, .unavailable: "lock"
            }
        }
    }

    static let enabledKey = "appLockEnabled"
    static let timingKey = "appLockAfter"

    private(set) var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    var timing: LockTiming {
        didSet { defaults.set(timing.rawValue, forKey: Self.timingKey) }
    }
    /// L-02 covers the app.
    private(set) var isLocked: Bool
    /// Private items open without asking again (D61).
    private(set) var privateUnlocked = false
    /// The last unlock failed: L-02 says so and pulses.
    private(set) var failures = 0
    /// Goes up with each successful unlock, for the success haptic.
    private(set) var unlocks = 0
    private(set) var method: Method

    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var isAuthenticating = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let authenticate: @MainActor (String) async -> Bool
    @ObservationIgnored private let readMethod: () -> Method

    init(defaults: UserDefaults = .nook, now: @escaping () -> Date = Date.init,
         method: @escaping () -> Method = AppLock.deviceMethod,
         authenticate: @escaping @MainActor (String) async -> Bool = AppLock.deviceAuthenticate) {
        self.defaults = defaults
        self.now = now
        self.readMethod = method
        self.authenticate = authenticate
        self.method = method()
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        timing = LockTiming(rawValue: defaults.integer(forKey: Self.timingKey)) ?? .immediately
        isLocked = enabled   // a cold launch with the lock on starts locked
    }

    /// The app-switcher cover: shown whenever Nook is locked, and whenever it isn't on screen
    /// while the lock is on or a Private item is open (L-02, PRD §9).
    func covers(_ phase: ScenePhase) -> Bool {
        isLocked || (phase != .active && (isEnabled || privateUnlocked))
    }

    func sceneChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = now()
            if !isEnabled { privateUnlocked = false }
            else if timing == .immediately { lock() }
        case .active:
            method = readMethod()   // a passcode can be set or removed in Settings meanwhile
            if isEnabled, let backgroundedAt, now().timeIntervalSince(backgroundedAt) >= Double(timing.rawValue) {
                lock()
            }
            backgroundedAt = nil
        default:
            break
        }
    }

    /// L-02's button, and its automatic try on appear.
    @discardableResult
    func unlock() async -> Bool {
        guard await ask(String(localized: "Unlock Nook")) else { return false }
        isLocked = false
        privateUnlocked = true
        return true
    }

    /// Opening a Private item (I-01, F-02). True straight away if already unlocked.
    @discardableResult
    func unlockPrivate() async -> Bool {
        if privateUnlocked { return true }
        guard await ask(String(localized: "See your private items")) else { return false }
        privateUnlocked = true
        return true
    }

    /// The user just made the item on screen Private (I-01's menu or editor): it's theirs and
    /// already showing, so it stays open until Nook leaves the screen, like any unlock.
    func keepPrivateOpen() {
        privateUnlocked = true
    }

    /// S-05's switch. Turning it on asks first (D15); if that fails it stays off.
    func setEnabled(_ on: Bool) async {
        if on {
            guard method != .unavailable, await ask(String(localized: "Lock Nook")) else { return }
            privateUnlocked = true
        }
        isEnabled = on
    }

    private func lock() {
        isLocked = true
        privateUnlocked = false
    }

    private func ask(_ reason: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let passed = await authenticate(reason)
        if passed { failures = 0; unlocks += 1 } else { failures += 1 }
        return passed
    }

    // MARK: The device

    /// Face ID or Touch ID, falling back to the passcode after repeated failures (01 L-02).
    static func deviceAuthenticate(_ reason: String) async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    nonisolated static func deviceMethod() -> Method {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return .unavailable }
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)   // fills biometryType
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcode
        }
    }

    #if DEBUG
    /// Previews: unlocked by a stand-in Face ID.
    static let preview = AppLock(defaults: UserDefaults(suiteName: "preview") ?? .standard,
                                 method: { .faceID }, authenticate: { _ in true })

    /// UI tests: `-uiTestingBiometrics success|failure|unavailable` stands in for Face ID.
    static func forTesting(_ arguments: [String]) -> AppLock? {
        guard let flag = arguments.firstIndex(of: "-uiTestingBiometrics"), flag + 1 < arguments.count else { return nil }
        let mode = arguments[flag + 1]
        return AppLock(method: { mode == "unavailable" ? .unavailable : .faceID },
                       authenticate: { _ in mode == "success" })
    }
    #endif
}
