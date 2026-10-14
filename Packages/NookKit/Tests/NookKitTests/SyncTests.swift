import CloudKit
import Foundation
import Synchronization
import SwiftData
import Testing
@testable import NookKit

// MARK: DedupeService (04 §4, D58)

/// The same backup restored on two devices: every row arrives twice with the same id.
@MainActor @Test func copiesMergeIntoOneWithEverythingKept() throws {
    let container = try NookStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let roomID = UUID(), itemID = UUID(), photoID = UUID()
    func room() -> Room {
        let room = Room(name: "Kitchen", symbol: "fork.knife", colorKey: "butter", order: 0)
        room.id = roomID
        context.insert(room)
        return room
    }
    func item(in room: Room, at date: Date) -> Item {
        let item = Item(name: "Kettle")
        (item.id, item.createdAt) = (itemID, date)
        context.insert(item)
        item.room = room
        let photo = Photo(fileName: "kettle.heic")
        photo.id = photoID
        context.insert(photo)
        photo.item = item
        return item
    }
    let first = room(), second = room()
    let early = item(in: first, at: .distantPast), late = item(in: second, at: .now)
    // Only the later copy was moved on its device: that history must survive.
    let move = LocationEvent(fromPath: "Kitchen", toPath: "Kitchen → Shelf", source: .manual)
    context.insert(move)
    move.item = late
    let mug = Item(name: "Mug")   // a different item in the second copy of the room
    context.insert(mug)
    mug.room = second
    try context.save()

    #expect(try DedupeService(context: context).run() == 3)   // a room, an item, a photo

    let rooms = try context.fetch(FetchDescriptor<Room>())
    let items = try context.fetch(FetchDescriptor<Item>())
    #expect(rooms.count == 1 && items.count == 2)
    let kettle = try #require(items.first { $0.id == itemID })
    #expect(kettle === early)
    #expect(kettle.photos?.count == 1 && kettle.events?.count == 1)
    #expect(Set((rooms[0].items ?? []).map(\.name)) == ["Kettle", "Mug"])
    #expect(try DedupeService(context: context).run() == 0)
}

@MainActor @Test func onboardingRoomsGetTheSameIDOnEveryDevice() throws {
    #expect(RoomPreset.onboardingID(for: "Kitchen") == RoomPreset.onboardingID(for: "Kitchen"))
    #expect(RoomPreset.onboardingID(for: "Kitchen") != RoomPreset.onboardingID(for: "Garage"))
    let container = try NookStore.makeContainer(inMemory: true)
    let rooms = RoomService(context: container.mainContext)
    let id = RoomPreset.onboardingID(for: "Kitchen")
    _ = try rooms.addRoom(named: "Kitchen", id: id)
    _ = try rooms.addRoom(named: "Kitchen", id: id)   // the other device's, after sync
    try container.mainContext.save()
    try DedupeService(context: container.mainContext).run()
    #expect(try rooms.rooms().count == 1)
}

// MARK: FileSync and BlobStore (D58)

@Test func recordNamesRoundTrip() throws {
    let id = FileSync.recordID(.receipts, "A1.pdf")
    #expect(id.recordName == "Receipts.A1.pdf" && id.zoneID.zoneName == "NookFiles")
    let file = try #require(FileSync.file(for: id))
    #expect(file.folder == .receipts && file.fileName == "A1.pdf")
    #expect(FileSync.file(for: CKRecord.ID(recordName: "Thumbs.A1.heic", zoneID: FileSync.zoneID)) == nil)
    #expect(FileSync.file(for: CKRecord.ID(recordName: "nonsense", zoneID: FileSync.zoneID)) == nil)
    #expect(FileSync.file(for: CKRecord.ID(recordName: "Photos.", zoneID: FileSync.zoneID)) == nil)
}

@Test func blobStoreReportsFilesButNotThumbnailsOrFilesFromICloud() throws {
    let blobs = temporaryBlobStore()
    let changes = Mutex<[BlobStore.Change]>([])
    blobs.observe { change in changes.withLock { $0.append(change) } }
    let photo = try blobs.savePhoto(jpeg(width: 64, height: 48))
    let copy = try blobs.copy(photo.fileName, in: .photos)
    blobs.remove([copy], in: .photos)
    blobs.remove([photo.fileName], in: .photos, reports: false)   // a delete that came from iCloud
    blobs.observe(nil)
    _ = try blobs.saveReceipt(jpeg(width: 40, height: 80))         // sync off: nothing reported
    #expect(changes.withLock { $0 } == [
        .init(kind: .saved, folder: .photos, fileName: photo.fileName),
        .init(kind: .saved, folder: .photos, fileName: copy),
        .init(kind: .removed, folder: .photos, fileName: copy),
    ])
}

@Test func adoptedFilesGetAThumbnail() throws {
    let blobs = temporaryBlobStore()
    let source = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
    try jpeg(width: 800, height: 600).write(to: source)
    try blobs.adopt(source, as: "arrived.heic", in: .photos)
    #expect(blobs.exists("arrived.heic", in: .photos))
    #expect(FileManager.default.fileExists(atPath: blobs.thumbnailURL(for: "arrived.heic").path))
}

@Test func cloudKitErrorsMapOntoS03() {
    #expect(SyncStatus.kind(of: CKError(.quotaExceeded)) == .storageFull)
    #expect(SyncStatus.kind(of: CKError(.notAuthenticated)) == .signedOut)
    #expect(SyncStatus.kind(of: NSError(domain: NSCocoaErrorDomain, code: 134400)) == .signedOut)
    #expect(SyncStatus.kind(of: CKError(.networkUnavailable)) == .failed)
}
