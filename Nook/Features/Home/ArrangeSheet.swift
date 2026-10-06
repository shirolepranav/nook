import SwiftUI
import SwiftData
import NookKit
import NookUI

/// Arrange rooms (H-07) and spots (H-02): drag handles to reorder; VoiceOver users get Move Up
/// and Move Down actions on each row. Done saves the order (`order`, PRD §8).
struct ArrangeSheet<Row: PersistentModel>: View {
    let title: LocalizedStringKey
    let load: (ModelContext) -> [Row]
    let save: (ModelContext, [Row]) -> Void
    let name: (Row) -> String
    let symbol: (Row) -> String
    let tint: (Row) -> Color

    @State private var order: [Row] = []
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(order) { row in
                    Label {
                        Text(verbatim: name(row)).font(.nookBody)
                    } icon: {
                        Image(systemName: symbol(row)).foregroundStyle(tint(row))
                    }
                    .frame(minHeight: NookLayout.rowHeight)
                    .listRowBackground(NookColor.surface)
                    .accessibilityActions {
                        if row.id != order.first?.id {
                            Button("Move Up") { move(row, by: -1) }
                        }
                        if row.id != order.last?.id {
                            Button("Move Down") { move(row, by: 1) }
                        }
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save(context, order)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .presentationSizing(.form)
        .onAppear { order = load(context) }
    }

    private func move(_ row: Row, by offset: Int) {
        guard let index = order.firstIndex(where: { $0.id == row.id }) else { return }
        let target = index + offset
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)
        AccessibilityNotification.Announcement(
            String(localized: "\(name(row)) moved to position \(target + 1) of \(order.count)")).post()
    }
}

extension ArrangeSheet where Row == Room {
    /// H-07 Arrange rooms.
    static var rooms: Self {
        Self(title: "Arrange Rooms",
             load: { (try? RoomService(context: $0).rooms()) ?? [] },
             save: { RoomService(context: $0).reorder($1) },
             name: \.name, symbol: \.symbol,
             tint: { (RoomColor(rawValue: $0.colorKey) ?? .stone).ink })
    }
}

extension ArrangeSheet where Row == Spot {
    /// H-02 drag to reorder spots.
    static func spots(in room: Room) -> Self {
        Self(title: "Arrange Spots",
             load: { RoomService(context: $0).spots(in: room) },
             save: { RoomService(context: $0).reorder($1) },
             name: \.name, symbol: { _ in "square.stack" },
             tint: { _ in (RoomColor(rawValue: room.colorKey) ?? .stone).ink })
    }
}

#Preview { ArrangeSheet.rooms.modelContainer(PreviewStore.seeded(.small)).nookAccent(.terracotta) }
