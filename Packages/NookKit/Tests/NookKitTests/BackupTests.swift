import Foundation
import SwiftData
import Testing
@testable import NookKit

// F9 `.nookbackup` (D12, D56): export, wipe, restore, compare; Merge and Replace; bad files.

private let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appending(path: "../../../../Fixtures/golden").standardized

private func temporaryFile(_ name: String = "Home.nookbackup") -> URL {
    FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(name)")
}

/// Every row as JSON, in id order, so two stores compare field by field.
@MainActor private func rows(_ context: ModelContext) throws -> Data {
    func sorted<M: BackupModel, R: BackupRecord>(_ type: M.Type, _ make: (M) -> R) throws -> [R] {
        try context.fetch(FetchDescriptor<M>()).map(make).sorted { $0.id.uuidString < $1.id.uuidString }
    }
    var data = BackupData()
    data.rooms = try sorted(Room.self, RoomRecord.init)
    data.spots = try sorted(Spot.self, SpotRecord.init)
    data.items = try sorted(Item.self, ItemRecord.init)
    data.photos = try sorted(Photo.self, PhotoRecord.init)
    data.receipts = try sorted(Receipt.self, ReceiptRecord.init)
    data.warranties = try sorted(Warranty.self, WarrantyRecord.init)
    data.events = try sorted(LocationEvent.self, EventRecord.init)
    data.loans = try sorted(Loan.self, LoanRecord.init)
    data.savedSearches = try sorted(SavedSearch.self, SavedSearchRecord.init)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(data)
}

private func files(_ blobs: BlobStore) -> [String: Data] {
    var all: [String: Data] = [:]
    for folder in BlobStore.Folder.allCases {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: blobs.url(of: folder).path)) ?? [] {
            all["\(folder.rawValue)/\(name)"] = try? Data(contentsOf: blobs.url(for: name, in: folder))
        }
    }
    return all
}

@MainActor @Test func roundTripRestoresEveryRowAndFile() async throws {
    let home = try HomeFixture()
    let url = temporaryFile()
    let manifest = try await BackupService(context: home.context, blobs: home.blobs)
        .export(to: url, appVersion: "1.0", homeName: "Maple Street", now: HomeFixture.now)
    #expect(manifest == BackupManifest(schemaVersion: 2, appVersion: "1.0", createdAt: HomeFixture.now, itemCount: 5,
                                       homeName: "Maple Street"))
    #expect(try BackupService.manifest(of: url) == manifest)

    let empty = try HomeFixture(seeded: false)
    let restored = try await BackupService(context: empty.context, blobs: empty.blobs).restore(from: url, mode: .replace)
    #expect(restored == 5)
    #expect(try rows(empty.context) == rows(home.context))
    #expect(files(empty.blobs) == files(home.blobs))
    #expect(files(home.blobs).count == 4)   // a photo, a receipt and their thumbnails
}

@MainActor @Test func mergeAddsOnlyWhatIsMissing() async throws {
    let home = try HomeFixture()
    let url = temporaryFile()
    try await BackupService(context: home.context, blobs: home.blobs).export(to: url, appVersion: "1.0", homeName: "")
    let drill = try #require(try home.context.fetch(FetchDescriptor<Item>()).first { $0.name == "Cordless drill" })
    drill.name = "Drill, renamed here"
    let mug = try #require(try home.context.fetch(FetchDescriptor<Item>()).first { $0.name.hasPrefix("Mug") })
    home.context.delete(mug)
    let added = Item(name: "Only on this phone")
    home.context.insert(added)
    try home.context.save()

    try await BackupService(context: home.context, blobs: home.blobs).restore(from: url, mode: .merge)
    let names = Set(try home.context.fetch(FetchDescriptor<Item>()).map(\.name))
    #expect(names.contains("Drill, renamed here") && !names.contains("Cordless drill"))   // kept what's here
    #expect(names.contains("Mug, \"Best Dad\"") && names.contains("Only on this phone"))  // added what's missing
    let restoredMug = try #require(try home.context.fetch(FetchDescriptor<Item>()).first { $0.name.hasPrefix("Mug") })
    #expect(restoredMug.spot?.name == "Bread bin" && restoredMug.room?.name == "Kitchen")  // linked to existing rows
}

@MainActor @Test func replaceSendsWhatIsHereToRecentlyDeleted() async throws {
    let home = try HomeFixture()
    let url = temporaryFile()
    try await BackupService(context: home.context, blobs: home.blobs).export(to: url, appVersion: "1.0", homeName: "")
    let rooms = RoomService(context: home.context)
    let attic = try rooms.addRoom(named: "Attic")
    var draft = ItemDraft(currencyCode: "USD", location: Location(room: attic))
    draft.name = "Only on this phone"
    let extra = try ItemService(context: home.context, blobs: home.blobs).create(draft)
    let kitchen = try #require(try home.context.fetch(FetchDescriptor<Room>()).first { $0.name == "Kitchen" })
    try rooms.delete(kitchen, rehoming: .recentlyDeleted)   // the backup brings it and its items back
    try home.context.save()

    try await BackupService(context: home.context, blobs: home.blobs).restore(from: url, mode: .replace)
    #expect(extra.deletedAt != nil)                                                // in Recently Deleted, not gone
    #expect(try home.context.fetch(FetchDescriptor<Room>()).map(\.name).sorted() == ["Garage", "Kitchen"])
    let espresso = try #require(try home.context.fetch(FetchDescriptor<Item>()).first { $0.name == "Espresso machine" })
    #expect(espresso.deletedAt == nil && espresso.spot?.name == "Counter")
}

@MainActor @Test func refusesNewerAndBrokenFiles() async throws {
    let home = try HomeFixture(seeded: false)
    let service = BackupService(context: home.context, blobs: home.blobs)

    let newer = temporaryFile()
    let writer = try ZipArchive.Writer(url: newer)
    try writer.add("manifest.json", data: Data(#"{"schemaVersion":99,"appVersion":"9","createdAt":0,"itemCount":0,"homeName":""}"#.utf8))
    try writer.finish()
    #expect(throws: BackupService.Failure.newerVersion) { try BackupService.manifest(of: newer) }

    let text = temporaryFile("notes.nookbackup")
    try Data("not a zip".utf8).write(to: text)
    await #expect(throws: BackupService.Failure.notABackup) { try await service.restore(from: text, mode: .merge) }

    let truncated = temporaryFile()
    let seeded = try HomeFixture()   // held: a released container's context traps
    try await BackupService(context: seeded.context, blobs: seeded.blobs).export(to: truncated, appVersion: "1", homeName: "")
    let bytes = try Data(contentsOf: truncated)
    try bytes.prefix(bytes.count / 2).write(to: truncated)
    await #expect(throws: BackupService.Failure.notABackup) { try await service.restore(from: truncated, mode: .merge) }
}

@Test func entryPathsCannotLeaveTheirFolder() throws {
    let folder = URL(fileURLWithPath: "/tmp/nook")
    #expect(try ZipArchive.safeURL(for: "a.heic", in: folder).path == "/tmp/nook/a.heic")
    for path in ["../a", "/etc/passwd", "a/../../b", "", "a\\..\\b"] {
        #expect(throws: ZipArchive.Failure.unsafePath) { try ZipArchive.safeURL(for: path, in: folder) }
    }
}

@Test func zipRoundTripsAndReadsDeflate() throws {
    let url = temporaryFile("t.zip")
    let writer = try ZipArchive.Writer(url: url)
    try writer.add("a.txt", data: Data("hello".utf8))
    try writer.add("empty", data: Data())
    try writer.add("dir/ü.bin", data: Data((0..<5_000).map { UInt8($0 % 251) }))
    try writer.finish()
    let reader = try ZipArchive.Reader(url: url)
    #expect(reader.entries.map(\.path) == ["a.txt", "empty", "dir/ü.bin"])
    #expect(try reader.data(#require(reader.entry("a.txt"))) == Data("hello".utf8))
    #expect(try reader.data(#require(reader.entry("empty"))).isEmpty)
    #expect(try reader.data(#require(reader.entry("dir/ü.bin"))).count == 5_000)

    // Made with /usr/bin/zip -9: what a Mac's re-zip produces.
    let deflated = try ZipArchive.Reader(url: fixtures.appending(path: "deflated.zip"))
    let text = try deflated.data(#require(deflated.entry("a.txt")))
    #expect(text.count == 1_450 && String(decoding: text, as: UTF8.self).hasPrefix("hello hello"))
    #expect(try deflated.data(#require(deflated.entry("empty.txt"))).isEmpty)
}

/// Like `SchemaTests`: a model field the backup doesn't carry would be lost on restore.
@MainActor @Test(arguments: Schema(versionedSchema: NookSchemaV2.self).entities.map(\.name))
func backupCarriesEveryField(entity name: String) throws {
    let schema = Schema(versionedSchema: NookSchemaV2.self)
    let entity = try #require(schema.entitiesByName[name])
    let home = try HomeFixture()
    func keys<R: BackupRecord>(_ make: (R.Model) -> R, _ type: R.Model.Type) throws -> Set<String> {
        let model = try #require(try home.context.fetch(FetchDescriptor<R.Model>()).first)
        return Set(Mirror(reflecting: make(model)).children.compactMap(\.label))
    }
    let records: [String: Set<String>] = [
        "Room": try keys(RoomRecord.init, Room.self), "Spot": try keys(SpotRecord.init, Spot.self),
        "Item": try keys(ItemRecord.init, Item.self), "Photo": try keys(PhotoRecord.init, Photo.self),
        "Receipt": try keys(ReceiptRecord.init, Receipt.self), "Warranty": try keys(WarrantyRecord.init, Warranty.self),
        "LocationEvent": try keys(EventRecord.init, LocationEvent.self), "Loan": try keys(LoanRecord.init, Loan.self),
        "SavedSearch": try keys(SavedSearchRecord.init, SavedSearch.self),
    ]
    let own = try #require(records[name])
    for attribute in entity.attributes {
        #expect(own.contains(attribute.name), "\(name).\(attribute.name) isn't in its backup record")
    }
    // Each relationship is carried as an id on one of its two sides.
    for relationship in entity.relationships {
        let inverse = relationship.inverseName.map { "\($0)ID" } ?? ""
        let other = records[relationship.destination] ?? []
        #expect(own.contains("\(relationship.name)ID") || other.contains(inverse),
                "\(name).\(relationship.name) isn't carried by either backup record")
    }
}
