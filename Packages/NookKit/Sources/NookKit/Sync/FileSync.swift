import CloudKit
import Foundation

/// Photo and receipt files in iCloud (Pro, 04 §5, D58). SwiftData mirrors the rows; the files
/// they name travel beside them as `NookFile` records, one `CKAsset` each, in their own zone of
/// the same private database, through a `CKSyncEngine`.
///
/// - New files go up when `BlobStore` writes them. Turning sync on for the first time queues
///   every file a row references.
/// - Removed files go away everywhere. `BlobStore.remove` is only called for final deletes
///   (D40) and discarded edits; `sweepOrphans` never sends anything.
/// - File names are unique and never rewritten, so there are no conflicts to merge.
/// - `CKSyncEngineDelegate` is `Sendable`, hence an actor (D59).
public actor FileSync: CKSyncEngineDelegate {
    public enum Event: Sendable {
        /// Files written here from iCloud; photo views reload.
        case arrived(Int)
        case sent
        case signedOut
        /// Another Apple Account signed in: sync turns off and its state is cleared.
        case switchedAccounts
        case storageFull
    }

    nonisolated static let zoneID = CKRecordZone.ID(zoneName: "NookFiles")
    nonisolated static let recordType = "NookFile"
    nonisolated static let assetKey = "asset"

    private let blobs: BlobStore
    private let database: CKDatabase
    private let stateURL: URL
    private let onEvent: @Sendable (Event) -> Void
    private var engine: CKSyncEngine?

    public init(blobs: BlobStore = .shared, containerID: String = SyncSettings.containerID,
                onEvent: @escaping @Sendable (Event) -> Void) {
        self.blobs = blobs
        self.database = CKContainer(identifier: containerID).privateCloudDatabase
        self.stateURL = blobs.root.appending(path: "FileSync.state")
        self.onEvent = onEvent
    }

    /// Starts the engine. On the very first start, `referenced` (the files rows point at) all
    /// go up; after that the saved state knows what's left to send.
    public func start(referenced: @Sendable () throws -> [(BlobStore.Folder, String)]) {
        guard engine == nil else { return }
        let state = (try? Data(contentsOf: stateURL)).flatMap {
            try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0)
        }
        var configuration = CKSyncEngine.Configuration(database: database, stateSerialization: state, delegate: self)
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        if state == nil {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
            let files = (try? referenced()) ?? []
            engine.state.add(pendingRecordZoneChanges: files.map { .saveRecord(Self.recordID($0.0, $0.1)) })
        }
        blobs.observe { [weak self] change in
            Task { await self?.enqueue(change) }
        }
    }

    /// Turning sync off keeps every file here and the saved state, so turning it back on
    /// carries on where it stopped.
    public func stop() {
        blobs.observe(nil)
        engine = nil
    }

    /// S-03's Sync Now.
    public func syncNow() async throws {
        guard let engine else { return }
        try await engine.fetchChanges()
        try await engine.sendChanges()
    }

    func enqueue(_ change: BlobStore.Change) {
        guard let engine else { return }
        let id = Self.recordID(change.folder, change.fileName)
        switch change.kind {
        case .saved:
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
        case .removed:
            // A room scan's full photo is saved and removed within seconds (D48): never send it.
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
            engine.state.add(pendingRecordZoneChanges: [.deleteRecord(id)])
        }
    }

    // MARK: Names

    /// "Photos.<uuid>.heic": the folder, then the file name.
    nonisolated static func recordID(_ folder: BlobStore.Folder, _ fileName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: folder.rawValue + "." + fileName, zoneID: zoneID)
    }

    nonisolated static func file(for id: CKRecord.ID) -> (folder: BlobStore.Folder, fileName: String)? {
        guard let dot = id.recordName.firstIndex(of: "."),
              let folder = BlobStore.Folder(rawValue: String(id.recordName[..<dot])), folder != .thumbs
        else { return nil }
        let fileName = String(id.recordName[id.recordName.index(after: dot)...])
        return fileName.isEmpty ? nil : (folder, fileName)
    }

    // MARK: CKSyncEngineDelegate

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            if let data = try? JSONEncoder().encode(update.stateSerialization) {
                try? data.write(to: stateURL, options: .atomic)
            }
        case .accountChange(let change):
            switch change.changeType {
            case .signOut:
                onEvent(.signedOut)
            case .switchAccounts:
                try? FileManager.default.removeItem(at: stateURL)
                onEvent(.switchedAccounts)
            default:
                break
            }
        case .fetchedRecordZoneChanges(let changes):
            var arrived = 0
            for modification in changes.modifications {
                let record = modification.record
                guard let (folder, fileName) = Self.file(for: record.recordID),
                      let source = (record[Self.assetKey] as? CKAsset)?.fileURL else { continue }
                if (try? blobs.adopt(source, as: fileName, in: folder)) != nil { arrived += 1 }
            }
            for deletion in changes.deletions {
                // ponytail: removed even if a row here still names it; deletes only follow final
                // deletes on another device. Check references first if that ever bites.
                if let (folder, fileName) = Self.file(for: deletion.recordID) {
                    blobs.remove([fileName], in: folder, reports: false)
                }
            }
            if arrived > 0 { onEvent(.arrived(arrived)) }
        case .sentRecordZoneChanges(let sent):
            for failure in sent.failedRecordSaves {
                switch failure.error.code {
                case .quotaExceeded:
                    onEvent(.storageFull)
                case .zoneNotFound, .userDeletedZone:
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(failure.record.recordID)])
                case .serverRecordChanged:
                    break   // already there: the same file under the same name
                default:
                    break   // the engine retries what can be retried
                }
            }
            if !sent.savedRecords.isEmpty || !sent.deletedRecordIDs.isEmpty { onEvent(.sent) }
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                          syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        let blobs = blobs
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { id in
            guard let (folder, fileName) = Self.file(for: id), blobs.exists(fileName, in: folder) else {
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])   // gone before it went up
                return nil
            }
            let record = CKRecord(recordType: Self.recordType, recordID: id)
            record[Self.assetKey] = CKAsset(fileURL: blobs.url(for: fileName, in: folder))
            return record
        }
    }
}
