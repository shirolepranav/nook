import Foundation

/// Whether the user's things live anywhere but this device (D65): S-01's status line and
/// Home's nudge. Nook can't see iOS's own iCloud Backup, so only sync and `.nookbackup` count.
public enum DataSafety: Equatable, Sendable {
    /// Syncing to iCloud; `lastSynced` is nil until the first pass ends.
    case inICloud(lastSynced: Date?)
    /// Sync is on but signed out, out of storage or failing: S-03 says why.
    case syncPaused
    /// A `.nookbackup` made within `recentBackup`.
    case backedUp(Date)
    case onlyHere

    /// A backup older than this no longer counts: a home changes a lot in three months.
    public static let recentBackup: TimeInterval = 90 * 24 * 3600

    /// `syncs` is S-03's switch with Pro (`SyncSettings.isActive`, live).
    public static func state(syncs: Bool, syncState: SyncStatus.State, lastSynced: Date?,
                             lastBackup: Date?, now: Date) -> DataSafety {
        if syncs {
            switch syncState {
            case .syncing, .upToDate: return .inICloud(lastSynced: lastSynced)
            case .signedOut, .storageFull, .failed: return .syncPaused
            }
        }
        if let lastBackup, now.timeIntervalSince(lastBackup) < recentBackup { return .backedUp(lastBackup) }
        return .onlyHere
    }
}

/// Home's one gentle card (D65): "Your 40 things live only on this iPhone." It shows once a
/// home is worth keeping, comes back once after a few months if dismissed, and never blocks.
public enum DataSafetyNudge {
    public static let itemThreshold = 20
    /// A room this full counts as the first finished room.
    public static let roomThreshold = 10
    public static let snooze: TimeInterval = 120 * 24 * 3600
    /// Not Now twice and it's gone for good; S-01's status line stays.
    public static let maxDismissals = 2

    /// `offered`: Pro was just bought from a flow other than S-03, so the card offers sync
    /// once, whatever the counts (D65).
    public static func isDue(safety: DataSafety, itemCount: Int, fullestRoom: Int, offered: Bool,
                             dismissals: Int, lastDismissed: Date?, now: Date) -> Bool {
        guard itemCount > 0 else { return false }
        switch safety {
        case .inICloud, .syncPaused: return false
        case .backedUp: if !offered { return false }
        case .onlyHere: break
        }
        if offered { return true }
        guard dismissals < maxDismissals,
              itemCount >= itemThreshold || fullestRoom >= roomThreshold else { return false }
        guard let lastDismissed else { return true }
        return now.timeIntervalSince(lastDismissed) >= snooze
    }
}
