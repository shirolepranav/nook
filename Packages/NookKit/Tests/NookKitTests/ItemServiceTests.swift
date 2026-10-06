import Foundation
import SwiftData
import Testing
@testable import NookKit

/// A store, its blobs and a clock the test can move.
@MainActor
private final class Fixture {
    let container: ModelContainer
    let blobs = temporaryBlobStore()
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    var context: ModelContext { container.mainContext }
    lazy var items = ItemService(context: context, blobs: blobs, now: { [unowned self] in self.now })
    lazy var rooms = RoomService(context: context)

    init() throws { container = try NookStore.makeContainer(inMemory: true) }

    func photo() throws -> ItemDraft.DraftPhoto {
        let saved = try blobs.savePhoto(jpeg(width: 64, height: 48))
        return .init(fileName: saved.fileName, width: saved.width, height: saved.height)
    }

    func draft(_ name: String, at location: Location? = nil, photos: Int = 0) throws -> ItemDraft {
        var draft = ItemDraft(currencyCode: "USD", location: location)
        draft.name = name
        draft.photos = try (0..<photos).map { _ in try photo() }
        return draft
    }
}

@MainActor @Test func onlyTheNameIsRequired() throws {
    let f = try Fixture()
    let mug = try f.items.create(f.draft("  Mug "))
    #expect(mug.name == "Mug" && mug.createdAt == f.now)
    #expect(throws: ItemService.Failure.emptyName) { try f.items.create(f.draft("   ")) }
}

@MainActor @Test func aPhotoAndANameMakeAnItem() throws {
    let f = try Fixture()
    let kitchen = try f.rooms.addRoom(named: "Kitchen")
    let counter = try f.rooms.addSpot(named: "Counter", in: kitchen)
    let item = try f.items.create(f.draft("Espresso machine", at: Location(room: kitchen, spot: counter), photos: 2))
    #expect(item.orderedPhotos.count == 2 && item.cover?.order == 0)
    #expect(item.room == kitchen && item.spot == counter)
    #expect(item.events?.count == 1 && item.events?.first?.toPath == "Kitchen → Counter")   // D38
    #expect(f.items.items(in: counter) == [item])
    #expect(f.items.looseItems(in: kitchen).isEmpty)
}

@MainActor @Test func tenPhotosAtMost() throws {
    let f = try Fixture()
    var draft = try f.draft("Lamp", photos: 10)
    #expect(try f.items.create(draft).photos?.count == 10)   // D7
    draft.photos.append(try f.photo())
    #expect(throws: ItemService.Failure.tooManyPhotos) { try f.items.create(draft) }
}

@MainActor @Test func editingKeepsPhotosInTheChosenOrder() throws {
    let f = try Fixture()
    let item = try f.items.create(f.draft("Lamp", photos: 3))
    var draft = ItemDraft(item)
    draft.photos = [draft.photos[2], draft.photos[0]]   // drop one, new cover
    draft.tags = ["  living ", ""]
    try f.items.update(item, from: draft)
    #expect(item.orderedPhotos.map(\.fileName) == draft.photos.map(\.fileName))
    #expect(item.tags == ["living"])
}

@MainActor @Test func setCoverAndRemovePhoto() throws {
    let f = try Fixture()
    let item = try f.items.create(f.draft("Lamp", photos: 3))
    let last = item.orderedPhotos[2]
    f.items.setCover(last)
    #expect(item.cover == last && item.orderedPhotos.map(\.order) == [0, 1, 2])
    f.items.removePhoto(last)
    #expect(item.photos?.count == 2)
}

@MainActor @Test func duplicatesCopyFieldsAndFilesButNotHistory() throws {
    let f = try Fixture()
    let kitchen = try f.rooms.addRoom(named: "Kitchen")
    let item = try f.items.create(f.draft("Kettle", at: Location(room: kitchen), photos: 1))
    let copy = try f.items.duplicate(item)
    #expect(copy.name == "Kettle" && copy.room == kitchen && copy.id != item.id)
    #expect(copy.cover?.fileName != item.cover?.fileName)
    #expect(fileCount(f.blobs, .photos) == 2)
    #expect(copy.events?.count == 1)   // its own "placed" event only
}

@MainActor @Test func deletedItemsWaitInRecentlyDeletedAndComeBack() throws {
    let f = try Fixture()
    let kitchen = try f.rooms.addRoom(named: "Kitchen")
    let mug = try f.items.create(f.draft("Mug", at: Location(room: kitchen)))
    f.items.delete([mug])
    #expect(f.items.allItems(in: kitchen).isEmpty)
    #expect(try f.items.deleted() == [mug])
    #expect(try f.items.recentlyAdded(limit: 5).isEmpty)
    f.now += 86_400 * 2
    #expect(f.items.daysLeft(mug) == 28)
    f.items.restore([mug])
    #expect(f.items.allItems(in: kitchen) == [mug])
}

/// D14, D40: after 30 days the row and its files are gone; a day earlier, nothing is.
@MainActor @Test func thePurgeRemovesItemsAndFilesAfter30Days() throws {
    let f = try Fixture()
    let mug = try f.items.create(f.draft("Mug", photos: 2))
    f.items.delete([mug])
    try f.context.save()
    f.now += 86_400 * 29
    try f.items.purgeExpired()
    #expect(try f.items.deleted().count == 1)
    f.now += 86_400
    try f.items.purgeExpired()
    try f.context.save()
    #expect(try f.items.deleted().isEmpty)
    #expect(try f.context.fetchCount(FetchDescriptor<Photo>()) == 0)
    #expect(fileCount(f.blobs, .photos) == 0 && fileCount(f.blobs, .thumbs) == 0)
}

@MainActor @Test func referencedFilesCoverPhotosAndReceipts() throws {
    let f = try Fixture()
    var draft = try f.draft("TV", photos: 1)
    draft.receipts = [.init(fileName: "r.pdf", kind: .pdf)]
    try f.items.create(draft)
    let files = try f.items.referencedFiles()
    #expect(files.photos == [draft.photos[0].fileName] && files.receipts == ["r.pdf"])
}

@MainActor @Test func tagsAndPrivateApplyToASelection() throws {
    let f = try Fixture()
    let a = try f.items.create(f.draft("A")), b = try f.items.create(f.draft("B"))
    f.items.addTag("Wedding", to: [a])
    f.items.addTag("wedding ", to: [a, b])          // no duplicate on a
    #expect(a.tags == ["Wedding"] && b.tags == ["wedding"])
    f.items.setPrivate([a, b], true)
    #expect(a.isPrivate && b.isPrivate)
}

/// D35: a soft delete is a property change, so a saved one undoes and stays undone.
@MainActor @Test func undoingASavedItemDeleteSurvivesTheNextSave() throws {
    let f = try Fixture()
    let mug = try f.items.create(f.draft("Mug"))
    try f.context.save()
    let undo = UndoManager()
    f.context.undoManager = undo
    f.items.delete([mug])
    try f.context.save()
    RunLoop.main.run(until: .now + 0.1)
    undo.undo()
    try f.context.save()
    #expect(mug.deletedAt == nil)
    #expect(try f.items.recentlyAdded(limit: 5).map(\.name) == ["Mug"])
}

/// D35 carry-over: undoing a spot delete brings its photo back.
@MainActor @Test func undoingASpotDeleteKeepsItsPhoto() throws {
    let f = try Fixture()
    let garage = try f.rooms.addRoom(named: "Garage")
    let shelf = try f.rooms.addSpot(named: "Shelf", in: garage)
    let photo = Photo(fileName: "shelf.heic")
    f.context.insert(photo)
    shelf.photo = photo
    try f.context.save()
    let undo = UndoManager()
    f.context.undoManager = undo
    try f.rooms.delete(shelf)
    try f.context.save()
    RunLoop.main.run(until: .now + 0.1)
    undo.undo()
    try f.context.save()
    #expect(f.rooms.spots(in: garage).first?.photo?.fileName == "shelf.heic")
}
