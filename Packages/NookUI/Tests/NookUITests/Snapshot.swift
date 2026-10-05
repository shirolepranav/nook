import SwiftUI
import Testing
import UIKit

// In-house snapshot testing (D31): no third-party dependency.
// Renders a view in a UIHostingController with trait overrides and compares it to a PNG in
// Fixtures/snapshots/NookUI/. A missing reference is recorded and the test fails once, so new
// references always get looked at. Re-record everything with TEST_RUNNER_SNAPSHOT_RECORD=1
// (xcodebuild passes TEST_RUNNER_ variables to the tests). A mismatch writes the new image to
// .build/snapshot-failures/.
// Nothing is written inside the package: new files there make xcodebuild reload the package
// and hang after the tests finish.
// References come from the iPhone SE (3rd generation) iOS 27.0 simulator; other devices
// render text slightly differently.

/// One appearance a component is checked in. Roadmap P1: light and dark, default and largest
/// text; plus Increase Contrast for components (05 §1).
struct SnapshotVariant: Sendable, CustomStringConvertible {
    let name: String
    let style: UIUserInterfaceStyle
    let size: UIContentSizeCategory
    let contrast: UIAccessibilityContrast

    static let light = SnapshotVariant(name: "light", style: .light, size: .large, contrast: .normal)
    static let dark = SnapshotVariant(name: "dark", style: .dark, size: .large, contrast: .normal)
    static let lightAX5 = SnapshotVariant(name: "light-ax5", style: .light,
                                          size: .accessibilityExtraExtraExtraLarge, contrast: .normal)
    static let darkAX5 = SnapshotVariant(name: "dark-ax5", style: .dark,
                                         size: .accessibilityExtraExtraExtraLarge, contrast: .normal)
    static let lightHC = SnapshotVariant(name: "light-hc", style: .light, size: .large, contrast: .high)

    static let all: [SnapshotVariant] = [.light, .dark, .lightAX5, .darkAX5, .lightHC]

    var description: String { name }
}

@MainActor
func assertSnapshot(
    of view: some View,
    named name: String,
    variant: SnapshotVariant,
    width: CGFloat = 375,
    filePath: String = #filePath,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let image = try render(view, variant: variant, width: width)
    let png = try #require(image.pngData())

    // filePath is <repo>/Packages/NookUI/Tests/NookUITests/<file>.swift
    var repo = URL(filePath: filePath)
    for _ in 0..<5 { repo.deleteLastPathComponent() }
    let folder = repo.appending(path: "Fixtures/snapshots/NookUI")
    let reference = folder.appending(path: "\(name).\(variant.name).png")
    let record = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"

    guard !record, let stored = try? Data(contentsOf: reference), let storedImage = UIImage(data: stored) else {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: reference)
        Issue.record("Recorded \(reference.lastPathComponent). Check it, then run the test again.",
                     sourceLocation: sourceLocation)
        return
    }

    let difference = differingPixels(image, storedImage)
    if difference > 0 {
        let failures = repo.appending(path: ".build/snapshot-failures")
        try FileManager.default.createDirectory(at: failures, withIntermediateDirectories: true)
        let failed = failures.appending(path: "\(name).\(variant.name).png")
        try png.write(to: failed)
        Issue.record("\(name) (\(variant)) differs from its reference in \(difference) pixels. See \(failed.lastPathComponent).",
                     sourceLocation: sourceLocation)
    }
}

@MainActor
private func render(_ view: some View, variant: SnapshotVariant, width: CGFloat) throws -> UIImage {
    let host = UIHostingController(rootView: view)
    host.traitOverrides.userInterfaceStyle = variant.style
    host.traitOverrides.preferredContentSizeCategory = variant.size
    host.traitOverrides.accessibilityContrast = variant.contrast

    // SwiftUI needs a window to lay out; it never appears on screen. Package tests have no
    // window scene for init(windowScene:), and UIWindow() is deprecated since iOS 26, so the
    // window is made through NSObject's initializer (test-only).
    let window = try #require((UIWindow.self as NSObject.Type).init() as? UIWindow)
    window.rootViewController = host
    window.isHidden = false

    let height = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    let bounds = CGRect(x: 0, y: 0, width: width, height: ceil(height))
    window.frame = bounds
    host.view.frame = bounds
    host.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = 2   // fixed, so references don't depend on the simulator's screen scale
    // layer.render, not drawHierarchy: package tests have no app scene, so the view never
    // reaches the render server and drawHierarchy draws a blank image.
    return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
        host.view.layer.render(in: context.cgContext)
    }
}

/// Counts pixels whose color differs by more than a small rounding tolerance.
private func differingPixels(_ a: UIImage, _ b: UIImage) -> Int {
    guard let pa = pixels(a), let pb = pixels(b), pa.width == pb.width, pa.height == pb.height else {
        return .max
    }
    var count = 0
    for i in stride(from: 0, to: pa.data.count, by: 4)
    where (0..<4).contains(where: { abs(Int(pa.data[i + $0]) - Int(pb.data[i + $0])) > 2 }) {
        count += 1
    }
    return count
}

private func pixels(_ image: UIImage) -> (data: [UInt8], width: Int, height: Int)? {
    guard let cg = image.cgImage else { return nil }
    let width = cg.width, height = cg.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = data.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            .map { $0.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height)); return true } ?? false
    }
    return drawn ? (data, width, height) : nil
}
