import SwiftUI
import Testing
@testable import NookUI

// The widgets (F10, W01Widgets board) at the iPhone SE's sizes, in the snapshot variants.
// The system draws the container, tinting and glass; these check the content. No AX5:
// the system caps text size in widgets, and the layouts shrink text to fit.

@MainActor private func widget(_ size: WidgetSize, @ViewBuilder _ content: () -> some View) -> some View {
    content()
        .padding(NookSpace.s2)
        .frame(width: size.previewSize.width, height: size.previewSize.height)
        .background(NookColor.surface)
        .nookAccent(.terracotta)
}

private let rows = [
    WidgetWarranty(id: UUID(), name: "Dishwasher", daysLeft: 12, end: .distantFuture, color: .sky),
    WidgetWarranty(id: UUID(), name: "Espresso machine", daysLeft: 26, end: .distantFuture, color: .clay),
    WidgetWarranty(id: UUID(), name: "Robot vacuum", daysLeft: 28, end: .distantFuture, color: .sage),
]

@MainActor
@Test(arguments: [SnapshotVariant.light, .dark, .lightHC])
func warrantiesWidget(variant: SnapshotVariant) throws {
    for (size, name) in [(WidgetSize.small, "small"), (.medium, "medium"), (.large, "large")] {
        try assertSnapshot(of: widget(size) { WarrantiesWidgetView(rows: rows, size: size) },
                           named: "WarrantiesWidget-\(name)", variant: variant, width: size.previewSize.width)
    }
    try assertSnapshot(of: widget(.small) { WarrantiesWidgetView(rows: [], size: .small) },
                       named: "WarrantiesWidget-empty", variant: variant, width: 148)
}

@MainActor
@Test(arguments: [SnapshotVariant.light, .dark, .lightHC])
func valueWidget(variant: SnapshotVariant) throws {
    let rooms = [WidgetRoomValue(name: "Kitchen", color: .clay, total: 4_210),
                 WidgetRoomValue(name: "Living room", color: .sky, total: 3_640),
                 WidgetRoomValue(name: "Bedroom", color: .lavender, total: 2_980)]
    for (size, name) in [(WidgetSize.small, "small"), (.medium, "medium")] {
        try assertSnapshot(of: widget(size) {
            ValueWidgetView(total: 12_480, currencyCode: "USD", itemCount: 124, rooms: rooms, size: size)
        }, named: "ValueWidget-\(name)", variant: variant, width: size.previewSize.width)
    }
}

@MainActor
@Test(arguments: [SnapshotVariant.light, .dark, .lightHC])
func quickFindWidget(variant: SnapshotVariant) throws {
    try assertSnapshot(of: widget(.small) { QuickFindWidgetView() }, named: "QuickFindWidget", variant: variant, width: 148)
}
