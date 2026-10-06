import Foundation
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

    public let root: URL
    private let cache = NSCache<NSString, CGImage>()

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
        return copy
    }

    public func remove(_ fileNames: [String], in folder: Folder) {
        for name in fileNames {
            try? FileManager.default.removeItem(at: url(for: name, in: folder))
            try? FileManager.default.removeItem(at: thumbnailURL(for: name))
            cache.removeObject(forKey: Self.thumbName(name) as NSString)
        }
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
    @concurrent
    public func thumbnail(_ fileName: String) async -> CGImage? {
        let key = Self.thumbName(fileName) as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(thumbnailURL(for: fileName) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// A photo downsampled to fit `maxPixels`, for the viewer (I-03).
    @concurrent
    public func image(_ fileName: String, in folder: Folder = .photos, maxPixels: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: fileName, in: folder) as CFURL, nil) else { return nil }
        return Self.downsampled(source, maxPixels: maxPixels)
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
