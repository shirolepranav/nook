import SwiftUI
import Testing
@testable import NookUI

// P3 item components in the 5 snapshot variants (05 §1).

@MainActor
@Test(arguments: SnapshotVariant.all)
func itemComponents(variant: SnapshotVariant) throws {
    let view = VStack(alignment: .leading, spacing: NookSpace.s2) {
        NookGrid {
            PhotoCard(name: "Blender", location: "Kitchen → Counter", isSelected: true)
            PhotoCard(name: "Toaster", location: "Kitchen → Counter", isSelected: false)
        }
        ItemRow(name: "Espresso machine", detail: Text(verbatim: "28 days left")) {
            Button(String("Restore")) {}.buttonStyle(.nookTertiary)
        }
        ItemRow(name: "Passport", detail: Text(verbatim: "Bedroom → Wardrobe"), isSelected: true)
        HStack(spacing: NookSpace.s1) {
            AddPhotoTile()
            PhotoTile(photo: nil, isCover: true)
        }
        StatusPill(.privateItem, Text(verbatim: "Private"))
    }
    .padding(NookSpace.s2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(NookColor.canvas)
    .nookAccent(.terracotta)
    try assertSnapshot(of: view, named: "Items", variant: variant)
}
