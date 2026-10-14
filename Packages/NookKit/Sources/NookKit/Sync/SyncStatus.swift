import CloudKit
import CoreData
import Foundation
import Observation

/// What S-03 shows (D58): read from the account, SwiftData's CloudKit events (D59) and
/// `FileSync`. Free and Off are decided by the screen from `EntitlementStore` and
/// `SyncSettings`.
@MainActor @Observable
public final class SyncStatus {
    public enum State: Equatable, Sendable {
        case syncing
        case upToDate
        case signedOut
        case storageFull
        case failed
    }

    public private(set) var state = State.upToDate
    /// "Last synced 2 min ago"; kept across launches.
    public private(set) var lastSynced: Date? {
        didSet { defaults.set(lastSynced, forKey: Self.lastSyncedKey) }
    }
    /// Bumped when files arrive from iCloud, so photo views reload their placeholders.
    public private(set) var arrivals = 0

    /// Runs after each import from another device: `DedupeService` (04 §4).
    @ObservationIgnored public var onImport: () -> Void = {}
    /// S-03's switch and Sync Now; the app owns the store, so it fills these in.
    @ObservationIgnored public var setSync: (Bool) async -> Void = { _ in }
    @ObservationIgnored public var syncNow: () async -> Void = {}

    static let lastSyncedKey = "iCloudLastSynced"
    @ObservationIgnored private let defaults = UserDefaults(suiteName: NookKit.appGroupID) ?? .standard
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var importDebounce: Task<Void, Never>?

    public init() {
        lastSynced = defaults.object(forKey: Self.lastSyncedKey) as? Date
    }

    /// Starts listening; call once a syncing store is open.
    public func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification,
                                            object: nil, queue: .main) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let summary = Self.summary(of: event)
            MainActor.assumeIsolated { self?.apply(summary) }
        })
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAccount() }
        })
        checkAccount()
    }

    public func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        importDebounce?.cancel()
    }

    public func handle(_ event: FileSync.Event) {
        switch event {
        case .arrived: arrivals += 1; finished()
        case .sent: finished()
        case .signedOut, .switchedAccounts: state = .signedOut
        case .storageFull: state = .storageFull
        }
    }

    public func checkAccount() {
        Task {
            let status = try? await CKContainer(identifier: SyncSettings.containerID).accountStatus()
            if status != .available { state = .signedOut } else if state == .signedOut { state = .upToDate }
        }
    }

    // MARK: Events

    /// What one CloudKit event means for S-03, worked out off the main actor.
    struct Summary: Sendable, Equatable {
        enum Kind: Sendable { case started, succeeded, signedOut, storageFull, failed }
        let kind: Kind
        let isImport: Bool
        let endDate: Date?
    }

    nonisolated static func summary(of event: NSPersistentCloudKitContainer.Event) -> Summary {
        let isImport = event.type == .import
        guard let endDate = event.endDate else { return Summary(kind: .started, isImport: isImport, endDate: nil) }
        guard let error = event.error else { return Summary(kind: .succeeded, isImport: isImport, endDate: endDate) }
        return Summary(kind: kind(of: error), isImport: isImport, endDate: endDate)
    }

    /// 134400 is Core Data's "no iCloud account" (D59).
    nonisolated static func kind(of error: Error) -> Summary.Kind {
        if let ck = error as? CKError {
            switch ck.code {
            case .quotaExceeded: return .storageFull
            case .notAuthenticated, .accountTemporarilyUnavailable: return .signedOut
            default: break
            }
            if let partial = ck.partialErrorsByItemID?.values.compactMap({ $0 as? CKError }),
               partial.contains(where: { $0.code == .quotaExceeded }) { return .storageFull }
        }
        if (error as NSError).code == 134400 { return .signedOut }
        return .failed
    }

    func apply(_ summary: Summary) {
        switch summary.kind {
        case .started:
            if state != .signedOut, state != .storageFull { state = .syncing }
        case .succeeded:
            finished(at: summary.endDate)
            if summary.isImport { scheduleDedupe() }
        case .signedOut: state = .signedOut
        case .storageFull: state = .storageFull
        case .failed: state = .failed
        }
    }

    private func finished(at date: Date? = nil) {
        state = .upToDate
        lastSynced = date ?? .now
    }

    /// One pass a second after the last import, not one per batch.
    private func scheduleDedupe() {
        importDebounce?.cancel()
        importDebounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.onImport()
        }
    }
}
