import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import NookKit

/// A solid-color JPEG, optionally tagged with an EXIF orientation (6 = rotated 90°).
func jpeg(width: Int, height: Int, orientation: Int = 1) -> Data {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: 0.8, green: 0.5, blue: 0.3, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!,
                               [kCGImagePropertyOrientation: orientation] as CFDictionary)
    CGImageDestinationFinalize(destination)
    return data as Data
}

func temporaryBlobStore() -> BlobStore {
    BlobStore(root: FileManager.default.temporaryDirectory.appending(path: "NookTests-\(UUID().uuidString)"))
}

func fileCount(_ blobs: BlobStore, _ folder: BlobStore.Folder) -> Int {
    (try? FileManager.default.contentsOfDirectory(atPath: blobs.url(of: folder).path).count) ?? 0
}
