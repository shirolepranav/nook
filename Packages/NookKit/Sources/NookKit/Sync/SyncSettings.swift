import Foundation

/// iCloud sync's switch (S-03), in the App Group's defaults. Sync runs only when it's on and
/// Pro is unlocked, so a refund stops it at the next launch and keeps every row (D58).
public enum SyncSettings {
    public static let containerID = "iCloud.pranav.nook"
    public static let key = "iCloudSync"
    static var defaults: UserDefaults { UserDefaults(suiteName: NookKit.appGroupID) ?? .standard }

    /// Off until the user turns it on (D58).
    public static var isOn: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }

    /// Whether this launch's store mirrors to CloudKit.
    public static var isActive: Bool { isOn && EntitlementCache.isPro }
}
