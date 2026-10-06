import SwiftUI
import Testing
@testable import NookUI

// Cards and the toast in the 5 snapshot variants (05 §1). The Capture button is Liquid Glass,
// which only the system compositor draws, so it's checked in the gallery instead.

@MainActor
private func canvas(@ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: NookSpace.s2, content: content)
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NookColor.canvas)
        .nookAccent(.terracotta)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func cards(variant: SnapshotVariant) throws {
    let view = canvas {
        NookGrid {
            PhotoCard(name: "Headphones", location: "Office → Desk")
            PhotoCard(name: "Passport and travel documents", location: "Bedroom → Wardrobe → Top shelf",
                      badges: [.privateItem, .endingSoon])
            RoomCard(name: "Kitchen", symbol: "fork.knife", color: .butter, itemCount: 48)
            RoomCard(name: "Garage", symbol: "car", color: .stone, itemCount: 0)
            AddCard(Text(verbatim: "Add room"))
        }
    }
    try assertSnapshot(of: view, named: "Cards", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func toast(variant: SnapshotVariant) throws {
    let view = canvas {
        ToastView(message: ToastMessage("Moved to Kitchen → Pantry.") {}) {}
        ToastView(message: ToastMessage("Saved to Garage.")) {}
    }
    try assertSnapshot(of: view, named: "Toast", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func answerCard(variant: SnapshotVariant) throws {
    let view = canvas {
        AnswerCard {
            Breadcrumb.text(["Office", "Desk", "Second drawer"], color: .sky, ending: ".")
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
            Text(verbatim: "Last confirmed Aug 3.").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            HStack(spacing: NookSpace.s1) { AnswerPhoto(nil); AnswerPhoto(nil) }
            Button(String("Move")) {}.buttonStyle(.nookPrimary)
        }
    }
    try assertSnapshot(of: view, named: "AnswerCard", variant: variant)
}
