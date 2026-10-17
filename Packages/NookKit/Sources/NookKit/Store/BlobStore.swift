import Foundation
import Synchronization
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Photo and receipt files on disk in the App Group (D7, 04 §5). The database keeps only file
/// names. Every file has a 400-px thumbnail in `Thumbs/` under the same base name, decoded
/// into an in-memory cache for scrolling (PRD §9).
///
/// Lifecycle (D40): files are written when picked, before the item is saved. Soft-deleted
/// items keep theirs; a purge removes them; `sweepOrphans` clears what no row references
/// (cancelled or killed edits).
public final class BlobStore: @unchecked Sendable {   // immutable, and NSCache is thread-safe
    public enum Folder: String, CaseIterable, Sendable {
        case photos = "Photos", thumbs = "Thumbs", receipts = "Receipts"
    }

    public enum Failure: Error, Equatable {
        case unreadableImage
        case unsupportedFile
        case writeFailed
    }

    /// What `savePhoto` wrote, for a `Photo` row.
    public struct Saved: Equatable, Sendable {
        public let fileName: String
        public let width: Int
        public let height: Int
    }

    public static let thumbnailPixels = 400
    /// ponytail: 12 MP is plenty for insurance photos; raise it if people zoom further.
    public static let photoPixels = 4032

    public static let shared = BlobStore(root: defaultRoot())

    /// A photo or receipt file written or removed, for `FileSync` (D58). Thumbnails aren't
    /// reported: each device makes its own.
    public struct Change: Hashable, Sendable {
        public enum Kind: Sendable { case saved, removed }
        public let kind: Kind
        public let folder: Folder
        public let fileName: String
    }

    public let root: URL
    private let cache = NSCache<NSString, CGImage>()
    /// One decode at a time, off the cooperative pool: parallel HEIC decodes deadlock ImageIO
    /// (`cacheImmediately` → `dispatch_sync`), first in P10's report and then in a fast-scrolled
    /// 1,000-card grid (P13, D63).
    // ponytail: serial; a small concurrency limit if large grids ever load visibly slowly.
    private let decoder = DispatchQueue(label: "pranav.nook.blobs.decode", qos: .userInitiated)
    private let observer = Mutex<(@Sendable (Change) -> Void)?>(nil)

    /// FileSync listens only while iCloud sync is on; `nil` stops it.
    public func observe(_ handler: (@Sendable (Change) -> Void)?) {
        observer.withLock { $0 = handler }
    }

    private func report(_ kind: Change.Kind, _ fileName: String, in folder: Folder) {
        guard folder != .thumbs, let handler = observer.withLock({ $0 }) else { return }
        handler(Change(kind: kind, folder: folder, fileName: fileName))
    }

    public init(root: URL) {
        self.root = root
        cache.countLimit = 600   // ~400 KB each decoded: a few screens of grid
        for folder in Folder.allCases {
            try? FileManager.default.createDirectory(at: url(of: folder), withIntermediateDirectories: true,
                                                     attributes: Self.protection)
        }
    }

    public func url(of folder: Folder) -> URL {
        root.appending(path: folder.rawValue, directoryHint: .isDirectory)
    }

    public func url(for fileName: String, in folder: Folder) -> URL {
        url(of: folder).appending(path: fileName)
    }

    /// The thumbnail of a photo or receipt shares its base name.
    public func thumbnailURL(for fileName: String) -> URL {
        url(for: Self.thumbName(fileName), in: .thumbs)
    }

    // MARK: Writing

    /// Re-encodes a photo as HEIC, upright, at most 12 MP, plus its thumbnail.
    public func savePhoto(_ data: Data) throws -> Saved {
        try saveImage(data, in: .photos)
    }

    /// Copies a receipt in: images become HEIC, PDFs are kept as they are. Both get a
    /// thumbnail (a PDF's first page).
    public func saveReceipt(from source: URL) throws -> (fileName: String, isPDF: Bool) {
        let scoped = source.startAccessingSecurityScopedResource()   // Files (I-02)
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let type = UTType(filenameExtension: source.pathExtension)
        if type?.conforms(to: .pdf) == true {
            let fileName = UUID().uuidString + ".pdf"
            let target = url(for: fileName, in: .receipts)
            do { try FileManager.default.copyItem(at: source, to: target) } catch { throw Failure.writeFailed }
            protect(target)
            if let page = Self.firstPage(of: target), let data = Self.heic(page) {
                try write(data, to: thumbnailURL(for: fileName))
            }
            report(.saved, fileName, in: .receipts)
            return (fileName, true)
        }
        guard type?.conforms(to: .image) ?? true else { throw Failure.unsupportedFile }
        let data: Data
        do { data = try Data(contentsOf: source) } catch { throw Failure.unreadableImage }
        return (try saveImage(data, in: .receipts).fileName, false)
    }

    /// A receipt photographed or picked from Photos.
    public func saveReceipt(_ data: Data) throws -> String {
        try saveImage(data, in: .receipts).fileName
    }

    /// A copy for Duplicate, under a new name.
    public func copy(_ fileName: String, in folder: Folder) throws -> String {
        let copy = UUID().uuidString + "." + (fileName as NSString).pathExtension
        do {
            try FileManager.default.copyItem(at: url(for: fileName, in: folder), to: url(for: copy, in: folder))
            if FileManager.default.fileExists(atPath: thumbnailURL(for: fileName).path) {
                try FileManager.default.copyItem(at: thumbnailURL(for: fileName), to: thumbnailURL(for: copy))
            }
        } catch { throw Failure.writeFailed }
        report(.saved, copy, in: folder)
        return copy
    }

    /// `reports` is false for a removal that came from iCloud, so it isn't sent back.
    public func remove(_ fileNames: [String], in folder: Folder, reports: Bool = true) {
        for name in fileNames {
            try? FileManager.default.removeItem(at: url(for: name, in: folder))
            try? FileManager.default.removeItem(at: thumbnailURL(for: name))
            cache.removeObject(forKey: Self.thumbName(name) as NSString)
            if reports { report(.removed, name, in: folder) }
        }
    }

    /// A file that arrived from iCloud (D58): copied into place, protected, with its
    /// thumbnail made here. It isn't reported back.
    public func adopt(_ source: URL, as fileName: String, in folder: Folder) throws {
        let target = url(for: fileName, in: folder)
        try? FileManager.default.removeItem(at: target)
        do { try FileManager.default.copyItem(at: source, to: target) } catch { throw Failure.writeFailed }
        protect(target)
        let thumb: CGImage? = fileName.lowercased().hasSuffix(".pdf")
            ? Self.firstPage(of: target)
            : CGImageSourceCreateWithURL(target as CFURL, nil).flatMap { Self.downsampled($0, maxPixels: Self.thumbnailPixels) }
        if let thumb, let data = Self.heic(thumb) { try write(data, to: thumbnailURL(for: fileName)) }
        cache.removeObject(forKey: Self.thumbName(fileName) as NSString)
    }

    public func exists(_ fileName: String, in folder: Folder) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName, in: folder).path)
    }

    /// Removes files that no row references (D40). Files younger than `grace` are kept: an
    /// editor may have written them and not saved yet.
    public func sweepOrphans(photos: Set<String>, receipts: Set<String>, grace: TimeInterval = 3600,
                             now: Date = .now) {
        let thumbs = Set((photos.union(receipts)).map(Self.thumbName))
        for (folder, keep) in [(Folder.photos, photos), (.receipts, receipts), (.thumbs, thumbs)] {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: url(of: folder), includingPropertiesForKeys: [.creationDateKey])) ?? []
            for file in files where !keep.contains(file.lastPathComponent) {
                let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                if now.timeIntervalSince(created) >= grace { try? FileManager.default.removeItem(at: file) }
            }
        }
    }

    // MARK: Reading

    /// The 400-px thumbnail, decoded off the main thread and cached.
    public func thumbnail(_ fileName: String) async -> CGImage? {
        let name = Self.thumbName(fileName)
        if let hit = cache.object(forKey: name as NSString) { return hit }
        let url = thumbnailURL(for: fileName)
        return await decode {
            let key = name as NSString
            if let hit = self.cache.object(forKey: key) { return hit }   // decoded while queued
            let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, options) else { return nil }
            self.cache.setObject(image, forKey: key)
            return image
        }
    }

    /// A photo downsampled to fit `maxPixels`, for the viewer (I-03).
    public func image(_ fileName: String, in folder: Folder = .photos, maxPixels: Int) async -> CGImage? {
        let url = url(for: fileName, in: folder)
        return await decode {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return Self.downsampled(source, maxPixels: maxPixels)
        }
    }

    private func decode(_ work: @escaping @Sendable () -> CGImage?) async -> CGImage? {
        await withCheckedContinuation { continuation in
            decoder.async { continuation.resume(returning: work()) }
        }
    }

    // MARK: Private

    private func saveImage(_ data: Data, in folder: Folder) throws -> Saved {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let full = Self.downsampled(source, maxPixels: Self.photoPixels),
              let thumb = Self.downsampled(source, maxPixels: Self.thumbnailPixels),
              let fullData = Self.heic(full), let thumbData = Self.heic(thumb)
        else { throw Failure.unreadableImage }
        let fileName = UUID().uuidString + ".heic"
        try write(fullData, to: url(for: fileName, in: folder))
        try write(thumbData, to: thumbnailURL(for: fileName))
        report(.saved, fileName, in: folder)
        return Saved(fileName: fileName, width: full.width, height: full.height)
    }

    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        let options: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        let options: Data.WritingOptions = [.atomic]
        #endif
        do { try data.write(to: url, options: options) } catch { throw Failure.writeFailed }   // e.g. disk full
    }

    private func protect(_ url: URL) {
        try? FileManager.default.setAttributes(Self.protection, ofItemAtPath: url.path)
    }

    /// PRD §9: readable after the first unlock, so widgets work.
    private static var protection: [FileAttributeKey: Any] {
        #if os(iOS)
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        #else
        [:]
        #endif
    }

    static func thumbName(_ fileName: String) -> String {
        (fileName as NSString).deletingPathExtension + ".heic"
    }

    /// Upright (EXIF orientation applied) and no larger than `maxPixels` on the long edge.
    private static func downsampled(_ source: CGImageSource, maxPixels: Int) -> CGImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private static func heic(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// A PDF's first page as a thumbnail-sized image, on white like paper.
    private static func firstPage(of url: URL) -> CGImage? {
        guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        let scale = CGFloat(thumbnailPixels) / max(box.width, box.height, 1)
        let width = Int(box.width * scale), height = Int(box.height * scale)
        guard width > 0, height > 0, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    private static func defaultRoot() -> URL {
        #if DEBUG
        // UI tests run on an in-memory store; their files go to a throwaway folder.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingStore") {
            return FileManager.default.temporaryDirectory.appending(path: "NookUITestBlobs")
        }
        #endif
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NookKit.appGroupID)
            ?? URL.applicationSupportDirectory
    }
}
