import CoreGraphics
import Foundation
import Testing
@testable import NookKit

@Test func photosAreSavedAsHEICWithASmallThumbnail() async throws {
    let blobs = temporaryBlobStore()
    let saved = try blobs.savePhoto(jpeg(width: 1600, height: 1200))
    #expect(saved.fileName.hasSuffix(".heic"))
    #expect((saved.width, saved.height) == (1600, 1200))
    let thumb = try #require(await blobs.thumbnail(saved.fileName))
    #expect(max(thumb.width, thumb.height) == BlobStore.thumbnailPixels)   // D7
    #expect(await blobs.thumbnail(saved.fileName) === thumb)               // cached
}

@Test func photosAreStoredUpright() throws {
    let saved = try temporaryBlobStore().savePhoto(jpeg(width: 200, height: 100, orientation: 6))
    #expect((saved.width, saved.height) == (100, 200))
}

@Test func hugePhotosAreScaledDown() throws {
    let saved = try temporaryBlobStore().savePhoto(jpeg(width: 6000, height: 4000))
    #expect(saved.width == BlobStore.photoPixels)
}

@Test func unreadableDataIsRejected() {
    #expect(throws: BlobStore.Failure.unreadableImage) { try temporaryBlobStore().savePhoto(Data("nope".utf8)) }
}

@Test func pdfReceiptsKeepTheirFileAndGetAThumbnail() async throws {
    let blobs = temporaryBlobStore()
    let pdf = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    let context = CGContext(pdf as CFURL, mediaBox: &box, nil)!
    context.beginPDFPage(nil); context.endPDFPage(); context.closePDF()
    let saved = try blobs.saveReceipt(from: pdf)
    #expect(saved.isPDF && saved.fileName.hasSuffix(".pdf"))
    #expect(FileManager.default.fileExists(atPath: blobs.url(for: saved.fileName, in: .receipts).path))
    #expect(await blobs.thumbnail(saved.fileName) != nil)
}

/// D40: files no row points at are swept, but not ones an open editor may still save.
@Test func theSweepRemovesOnlyOldOrphans() throws {
    let blobs = temporaryBlobStore()
    let kept = try blobs.savePhoto(jpeg(width: 50, height: 50))
    _ = try blobs.savePhoto(jpeg(width: 50, height: 50))
    blobs.sweepOrphans(photos: [kept.fileName], receipts: [])               // the orphan is too new
    #expect(fileCount(blobs, .photos) == 2)
    blobs.sweepOrphans(photos: [kept.fileName], receipts: [], now: .now + 7200)
    #expect(fileCount(blobs, .photos) == 1 && fileCount(blobs, .thumbs) == 1)
}
