import SwiftUI
import Testing
@testable import NookUI

// P6 capture pieces in the 5 snapshot variants (05 §1). The camera is drawn as a dark
// stand-in, as on the boards. CameraControl is Liquid Glass, which only the system
// compositor draws, so it's checked in the gallery.

@MainActor private func onCamera(@ViewBuilder _ content: () -> some View) -> some View {
    content()
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.85))   // a camera feed is dark in both modes
        .background(NookColor.canvas)
        .nookAccent(.terracotta)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func detectionOutlines(variant: SnapshotVariant) throws {
    let view = onCamera {
        DetectionOverlay(boxes: [CGRect(x: 0.05, y: 0.1, width: 0.4, height: 0.7),
                                 CGRect(x: 0.55, y: 0.25, width: 0.38, height: 0.5)],
                         names: ["Toaster", "Blender"], selected: 1, reveals: false)
            .frame(height: 180)
            .background(NookColor.surfaceSunken)
    }
    try assertSnapshot(of: view, named: "DetectionOutline", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func scanHighlights(variant: SnapshotVariant) throws {
    let view = VStack(alignment: .leading, spacing: NookSpace.s1) {
        ScanHighlight(Text(verbatim: "$766.41"), size: CGSize(width: 70, height: 18), isBest: true) {}
        ScanHighlight(Text(verbatim: "708.00"), size: CGSize(width: 60, height: 18)) {}
        ScanHighlight(Text(verbatim: "09/14/2026"), size: CGSize(width: 90, height: 18), isUsed: true) {}
    }
    .padding(NookSpace.s2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(NookColor.surfaceRaised)
    .nookAccent(.terracotta)
    try assertSnapshot(of: view, named: "ScanHighlight", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func cameraControls(variant: SnapshotVariant) throws {
    let view = onCamera {
        HStack(spacing: NookSpace.s3) {
            PhotoCounter(count: 3, thumbnail: nil)
            ShutterButton {}
        }
    }
    try assertSnapshot(of: view, named: "ShutterButton", variant: variant)
}
