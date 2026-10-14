import Observation

/// What the Free tier allows (D9). Every limit is decided here, never in a view (CLAUDE.md).
///
/// P10: everyone is Pro until the paywall exists, as the 25-item and 3-reminder limits wait
/// for it too (D39, D50, D56). UI tests pass `-uiTestingFree YES` to see the free states.
// P11: Transaction.currentEntitlements, cached for offline use (PRD §7).
@MainActor @Observable
public final class EntitlementStore {
    public var isPro: Bool

    public init(isPro: Bool = true) {
        self.isPro = isPro
    }

    /// The insurance report, the proof pack and CSV (F9). Free users get a watermarked first
    /// page (PRD §7).
    public var canExport: Bool { isPro }
    /// `.nookbackup` (F9, PRD §7). Restoring is never gated: it's the user's own data.
    public var canBackUp: Bool { isPro }
}
