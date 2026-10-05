import SwiftUI
import Testing
@testable import NookUI

// Each core component in every state it has, in the 5 snapshot variants (05 §1).

/// Lays components out on the canvas the way a screen would.
@MainActor private func specimen(@ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: NookSpace.s2, content: content)
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NookColor.canvas)
        .nookAccent(.terracotta)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func buttons(variant: SnapshotVariant) throws {
    let view = specimen {
        Button("Save") {}.buttonStyle(.nookPrimary)
        Button {} label: { Text(verbatim: "Scan a room").frame(maxWidth: .infinity) }.buttonStyle(.nookPrimary)
        Button("Add spot") {}.buttonStyle(.nookSecondary)
        Button("Cancel") {}.buttonStyle(.nookTertiary)
        Button("Delete") {}.buttonStyle(.nookDestructive)
        Button("Unlock Pro") {}.buttonStyle(.nookPrimary).disabled(true)
        Button("Save All") {}.buttonStyle(NookButtonStyle(.primary, isLoading: true))
    }
    try assertSnapshot(of: view, named: "Buttons", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func chips(variant: SnapshotVariant) throws {
    let view = specimen {
        HStack(spacing: NookSpace.s1) {
            FilterChip(verbatim: "Garage", isSelected: true) {}
            FilterChip(verbatim: "Kitchen", isSelected: false) {}
        }
        HStack(spacing: NookSpace.s1) {
            RoomChip(name: "Office", symbol: "desktopcomputer", color: .sky, isSelected: true) {}
            RoomChip(name: "Garage", symbol: "car", color: .stone, isSelected: false) {}
        }
    }
    try assertSnapshot(of: view, named: "Chips", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func pillsAndBadges(variant: SnapshotVariant) throws {
    let view = specimen {
        StatusPill(.active, Text(verbatim: "Active until 2027"))
        StatusPill(.endingSoon, Text(verbatim: "Ends in 12 days"))
        StatusPill(.expired, Text(verbatim: "Expired Mar 3"))
        StatusPill(.lent, Text(verbatim: "Lent to Jordan"))
        HStack(spacing: NookSpace.s1) {
            CardBadge(.privateItem)
            CardBadge(.lent)
            CardBadge(.endingSoon)
        }
    }
    try assertSnapshot(of: view, named: "PillsAndBadges", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func textFields(variant: SnapshotVariant) throws {
    let view = specimen {
        NookTextField(Text(verbatim: "Name"), text: .constant(""), prompt: Text(verbatim: "Coffee machine"))
        NookTextField(Text(verbatim: "Serial number"), text: .constant("SN-4821-77"),
                      helper: Text(verbatim: "Usually on a sticker underneath."))
        NookTextField(Text(verbatim: "Price"), text: .constant("12,50,0"),
                      error: Text(verbatim: "That doesn't look like a price."))
    }
    try assertSnapshot(of: view, named: "TextFields", variant: variant)
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func states(variant: SnapshotVariant) throws {
    let view = specimen {
        EmptyStateView(.shelfWaiting, title: Text(verbatim: "Let’s start with one room."),
                       message: Text(verbatim: "Scan a shelf and tag what’s on it. It takes about 30 seconds.")) {
            Button {} label: {
                Label { Text(verbatim: "Scan a room") } icon: { Image(systemName: "viewfinder") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
        }
        ErrorStateView(title: Text(verbatim: "Your rooms didn’t load"),
                       message: Text(verbatim: "Your items are safe on this iPhone. Try again in a moment.")) {}
        HStack(spacing: NookSpace.s2) {
            SkeletonCard()
            SkeletonCard()
        }
    }
    try assertSnapshot(of: view, named: "States", variant: variant)
}
