import Foundation
import SwiftData

/// `manifest.json` in a `.nookbackup` (D12, 04 §5): read first, so S-04 can ask "Restore
/// "Maple Street, Oct 1"?" before anything changes.
public struct BackupManifest: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var appVersion: String
    public var createdAt: Date
    public var itemCount: Int
    public var homeName: String
}

/// S-04: one `.nookbackup` file with every row, photo and receipt (F9), and restoring one by
/// Merge or Replace (D56). Records are read and written on the main context; the zip and the
/// files are handled off the main actor.
// ponytail: main-context reads and writes, not a @ModelActor (04 §10); fine for thousands of
// rows. Move to a @ModelActor if a restore is ever measured blocking the UI.
@MainActor
public struct BackupService {
    public enum Mode: Sendable {
        /// "Keep what's here and add what's missing": only rows whose id is new are added.
        case merge
        /// "Move what's here to Recently Deleted first": then the backup's rows are written
        /// over the store's, so restoring this device's own backup brings its items back.
        case replace
    }

    public enum Failure: Error, Equatable {
        case notABackup
        case newerVersion
        case notEnoughSpace
        case writeFailed
    }

    public nonisolated static let fileExtension = "nookbackup"
    /// `NookSchemaV2`.
    public nonisolated static let schemaVersion = 2

    let context: ModelContext
    let blobs: BlobStore

    public init(context: ModelContext, blobs: BlobStore = .shared) {
        self.context = context
        self.blobs = blobs
    }

    // MARK: Create

    /// Writes the backup to `url`. Cancelling the task stops it and removes the file.
    @discardableResult
    public func export(to url: URL, appVersion: String, homeName: String, now: Date = .now,
                       progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> BackupManifest {
        var data = BackupData()
        data.rooms = try fetch(Room.self).map(RoomRecord.init)
        data.spots = try fetch(Spot.self).map(SpotRecord.init)
        data.items = try fetch(Item.self).map(ItemRecord.init)
        data.photos = try fetch(Photo.self).map(PhotoRecord.init)
        data.receipts = try fetch(Receipt.self).map(ReceiptRecord.init)
        data.warranties = try fetch(Warranty.self).map(WarrantyRecord.init)
        data.events = try fetch(LocationEvent.self).map(EventRecord.init)
        data.loans = try fetch(Loan.self).map(LoanRecord.init)
        data.savedSearches = try fetch(SavedSearch.self).map(SavedSearchRecord.init)
        let manifest = BackupManifest(schemaVersion: Self.schemaVersion, appVersion: appVersion, createdAt: now,
                                      itemCount: data.items.filter { $0.deletedAt == nil }.count, homeName: homeName)
        let files = referencedFiles(data)
        let blobs = blobs
        try await Task.detached {
            do {
                let writer = try ZipArchive.Writer(url: url)
                try writer.add("manifest.json", data: Self.encoder.encode(manifest))
                try writer.add("data.json", data: Self.encoder.encode(data))
                for (index, file) in files.enumerated() {
                    try Task.checkCancellation()
                    let source = blobs.url(for: file.name, in: file.folder)
                    guard FileManager.default.fileExists(atPath: source.path) else { continue }   // a lost file isn't fatal
                    try writer.add("files/\(file.folder.rawValue)/\(file.name)", file: source)
                    progress(Double(index + 1) / Double(files.count))
                }
                try writer.finish()
            } catch {
                try? FileManager.default.removeItem(at: url)
                if error is CancellationError { throw error }
                throw (error as? CocoaError)?.code == .fileWriteOutOfSpace ? Failure.notEnoughSpace : Failure.writeFailed
            }
        }.value
        return manifest
    }

    /// "About 1.2 GB" on S-04: the files a backup would carry.
    public func estimatedSize() throws -> Int64 {
        let photos = try fetch(Photo.self).map(PhotoRecord.init)
        let receipts = try fetch(Receipt.self).map(ReceiptRecord.init)
        var data = BackupData()
        (data.photos, data.receipts) = (photos, receipts)
        return referencedFiles(data).reduce(Int64(0)) { total, file in
            let size = try? blobs.url(for: file.name, in: file.folder).resourceValues(forKeys: [.fileSizeKey]).fileSize
            return total + Int64(size ?? 0)
        }
    }

    // MARK: Restore

    /// The backup's manifest, without changing anything.
    public nonisolated static func manifest(of url: URL) throws -> BackupManifest {
        try scoped(url) {
            let reader = try open(url)
            return try readManifest(reader)
        }
    }

    /// Restores a backup and returns how many items it holds. Files are copied first, so a
    /// failure leaves the records untouched.
    @discardableResult
    public func restore(from url: URL, mode: Mode) async throws -> Int {
        let blobs = blobs
        let data = try await Task.detached { () throws -> BackupData in
            try Self.scoped(url) {
                let reader = try Self.open(url)
                _ = try Self.readManifest(reader)
                guard let entry = reader.entry("data.json"),
                      let data = try? Self.decoder.decode(BackupData.self, from: reader.data(entry))
                else { throw Failure.notABackup }
                for entry in reader.entries where entry.path.hasPrefix("files/") {
                    try Task.checkCancellation()
                    let parts = entry.path.split(separator: "/")
                    guard parts.count == 3, let folder = BlobStore.Folder(rawValue: String(parts[1])) else { continue }
                    let target = try ZipArchive.safeURL(for: String(parts[2]), in: blobs.url(of: folder))
                    guard !FileManager.default.fileExists(atPath: target.path) else { continue }   // ids: same name, same file
                    do {
                        try reader.data(entry).write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                    } catch let error as ZipArchive.Failure {
                        throw error == .unsafePath ? Failure.notABackup : error
                    } catch {
                        throw (error as? CocoaError)?.code == .fileWriteOutOfSpace ? Failure.notEnoughSpace : Failure.writeFailed
                    }
                }
                return data
            }
        }.value
        if mode == .replace { try clear(keeping: data) }
        apply(data, overwrite: mode == .replace)
        try context.save()
        context.undoManager?.removeAllActions()   // a restore isn't one step to undo
        return data.items.filter { $0.deletedAt == nil }.count
    }

    /// Replace's first step: what the backup doesn't have goes to Recently Deleted, as when a
    /// room is deleted with its items (D28).
    private func clear(keeping data: BackupData) throws {
        let roomIDs = Set(data.rooms.map(\.id)), spotIDs = Set(data.spots.map(\.id)), itemIDs = Set(data.items.map(\.id))
        let rooms = RoomService(context: context)
        for room in try fetch(Room.self) where !roomIDs.contains(room.id) {
            try rooms.delete(room, rehoming: .recentlyDeleted)
        }
        // Spots in kept rooms; a container goes with its spot.
        for spot in try fetch(Spot.self) where !spotIDs.contains(spot.id) {
            guard let room = spot.room, roomIDs.contains(room.id), spot.parent.map({ spotIDs.contains($0.id) }) ?? true else { continue }
            try rooms.delete(spot, rehoming: .recentlyDeleted)
        }
        ItemService(context: context, blobs: blobs).delete(try fetch(Item.self).filter { !itemIDs.contains($0.id) })
    }

    private func apply(_ data: BackupData, overwrite: Bool) {
        let rows = BackupRows()
        let rooms = upsert(data.rooms, overwrite: overwrite)
        rows.rooms = rooms.all
        let spots = upsert(data.spots, overwrite: overwrite)
        rows.spots = spots.all
        let items = upsert(data.items, overwrite: overwrite)
        rows.items = items.all
        let photos = upsert(data.photos, overwrite: overwrite)
        let receipts = upsert(data.receipts, overwrite: overwrite)
        let warranties = upsert(data.warranties, overwrite: overwrite)
        let events = upsert(data.events, overwrite: overwrite)
        let loans = upsert(data.loans, overwrite: overwrite)
        _ = upsert(data.savedSearches, overwrite: overwrite)
        // Only rows this restore wrote get the backup's links; Merge leaves existing rows alone.
        for (record, model) in spots.written { record.link(model, rows) }
        for (record, model) in items.written { record.link(model, rows) }
        for (record, model) in photos.written { record.link(model, rows) }
        for (record, model) in receipts.written { record.link(model, rows) }
        for (record, model) in warranties.written { record.link(model, rows) }
        for (record, model) in events.written { record.link(model, rows) }
        for (record, model) in loans.written { record.link(model, rows) }
    }

    /// Adds the records whose id is new; with `overwrite`, also writes over the ones that exist.
    private func upsert<R: BackupRecord>(_ records: [R], overwrite: Bool) -> (all: [UUID: R.Model], written: [(R, R.Model)]) {
        var all = Dictionary((try? context.fetch(FetchDescriptor<R.Model>()))?.map { ($0.id, $0) } ?? [],
                             uniquingKeysWith: { first, _ in first })
        var written: [(R, R.Model)] = []
        for record in records {
            if let existing = all[record.id] {
                guard overwrite else { continue }
                record.write(to: existing)
                written.append((record, existing))
            } else {
                let model = record.makeModel()
                record.write(to: model)
                context.insert(model)
                all[record.id] = model
                written.append((record, model))
            }
        }
        return (all, written)
    }

    // MARK: Helpers

    private func fetch<M: PersistentModel>(_ type: M.Type) throws -> [M] {
        try context.fetch(FetchDescriptor<M>())
    }

    /// Each photo and receipt, and its thumbnail (D7).
    private func referencedFiles(_ data: BackupData) -> [(folder: BlobStore.Folder, name: String)] {
        let photos = Set(data.photos.map(\.fileName)).subtracting([""]).sorted()
        let receipts = Set(data.receipts.map(\.fileName)).subtracting([""]).sorted()
        return photos.map { (.photos, $0) } + receipts.map { (.receipts, $0) }
            + (photos + receipts).map { (.thumbs, BlobStore.thumbName($0)) }
    }

    private nonisolated static func open(_ url: URL) throws -> ZipArchive.Reader {
        do { return try ZipArchive.Reader(url: url) } catch { throw Failure.notABackup }
    }

    private nonisolated static func readManifest(_ reader: ZipArchive.Reader) throws -> BackupManifest {
        guard let entry = reader.entry("manifest.json"),
              let manifest = try? decoder.decode(BackupManifest.self, from: reader.data(entry))
        else { throw Failure.notABackup }
        guard manifest.schemaVersion <= schemaVersion else { throw Failure.newerVersion }
        return manifest
    }

    /// A file from Files or the share sheet (S-04).
    private nonisolated static func scoped<T>(_ url: URL, _ work: () throws -> T) throws -> T {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try work()
    }

    // Dates as seconds, so a round trip is exact.
    private nonisolated static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private nonisolated static var decoder: JSONDecoder { JSONDecoder() }
}
