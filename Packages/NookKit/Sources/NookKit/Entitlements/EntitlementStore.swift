import Foundation
import Observation
import StoreKit

/// The last known Pro state, in the App Group's defaults: read at launch so there's no flash
/// of the Free state, offline too (PRD §7), and by services that enforce the limits
/// (`ItemService`) and, in P12, widgets and intents.
public enum EntitlementCache {
    static let key = "isPro"
    static var defaults: UserDefaults { UserDefaults(suiteName: NookKit.appGroupID) ?? .standard }

    public static var isPro: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

/// What the Free tier allows (D9, D58) and whether this Apple Account owns Nook Pro. Every
/// limit is decided here, never in a view (CLAUDE.md).
///
/// Pro is the one-time non-consumable `productID`, read from `Transaction.currentEntitlements`
/// and kept current by `Transaction.updates` (Ask to Buy approvals, refunds, Family Sharing).
@MainActor @Observable
public final class EntitlementStore {
    public nonisolated static let productID = "pranav.nook.pro"
    public nonisolated static let freeItemLimit = 25
    public nonisolated static let freeReminderLimit = 3

    /// How Pro came to this account, for S-02's line.
    public enum Ownership: Equatable, Sendable {
        case purchased(Date)
        case familyShared(Date)
    }

    public private(set) var isPro: Bool {
        didSet { if isPro != oldValue { EntitlementCache.isPro = isPro } }
    }
    public private(set) var ownership: Ownership?

    /// `forcedPro` pins the state and skips StoreKit: UI tests, previews and unit tests.
    private let forced: Bool
    @ObservationIgnored private var updates: Task<Void, Never>?

    public init(forcedPro: Bool? = nil) {
        forced = forcedPro != nil
        isPro = forcedPro ?? EntitlementCache.isPro
        EntitlementCache.isPro = isPro
        guard !forced else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Reads the current entitlement. A revoked (refunded) purchase isn't Pro. Without a
    /// network StoreKit answers from its own cache, so this works offline.
    public func refresh() async {
        guard !forced else { return }
        var found: Ownership?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            found = transaction.ownershipType == .familyShared
                ? .familyShared(transaction.purchaseDate) : .purchased(transaction.purchaseDate)
        }
        ownership = found
        isPro = found != nil
    }

    /// A purchase that just finished (P-01): unlock at once rather than wait for `updates`.
    public func didPurchase(_ transaction: Transaction) async {
        await transaction.finish()
        if forced { isPro = true } else { await refresh() }
    }

    /// Restore Purchases (P-01, S-02). Returns whether Pro was found.
    @discardableResult
    public func restore() async -> Bool {
        guard !forced else { return isPro }
        try? await AppStore.sync()
        await refresh()
        return isPro
    }

    #if DEBUG
    /// UI tests' stand-in for a purchase (`-uiTestingPurchase success`).
    public func unlockForTesting() { isPro = true }
    #endif

    // MARK: Limits (D9, D58)

    /// The insurance report, the proof pack and CSV (F9). Free users get a watermarked first
    /// page (PRD §7).
    public var canExport: Bool { isPro }
    /// iCloud sync (S-03).
    public var canSync: Bool { isPro }

    /// Free keeps up to 25 items; the next save opens P-01 (PRD §7).
    public nonisolated static func canAddItems(isPro: Bool, existing: Int, adding: Int = 1) -> Bool {
        isPro || existing + adding <= freeItemLimit
    }

    /// Free keeps up to 3 active warranty reminders (D9).
    public nonisolated static func canAddReminder(isPro: Bool, active: Int) -> Bool {
        isPro || active < freeReminderLimit
    }
}
