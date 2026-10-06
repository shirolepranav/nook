import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-07 Arrange rooms: drag handles to reorder; VoiceOver users get Move Up and Move Down
/// actions on each room. Done saves the order (`Room.order`, PRD §8).
struct ArrangeRoomsSheet: View {
    @State private var order: [Room] = []
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(order) { room in
                    Label {
                        Text(verbatim: room.name).font(.nookBody)
                    } icon: {
                        Image(systemName: room.symbol)
                            .foregroundStyle((RoomColor(rawValue: room.colorKey) ?? .stone).ink)
                    }
                    .frame(minHeight: NookLayout.rowHeight)
                    .listRowBackground(NookColor.surface)
                    .accessibilityActions {
                        if room.id != order.first?.id {
                            Button("Move Up") { move(room, by: -1) }
                        }
                        if room.id != order.last?.id {
                            Button("Move Down") { move(room, by: 1) }
                        }
                    }
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .navigationTitle("Arrange Rooms")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: save) }
            }
        }
        .presentationSizing(.form)
        .onAppear { order = (try? RoomService(context: context).rooms()) ?? [] }
    }

    private func move(_ room: Room, by offset: Int) {
        guard let index = order.firstIndex(where: { $0.id == room.id }) else { return }
        let target = index + offset
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)
        AccessibilityNotification.Announcement(
            String(localized: "\(room.name) moved to position \(target + 1) of \(order.count)")).post()
    }

    private func save() {
        RoomService(context: context).reorder(order)
        try? context.save()
        dismiss()
    }
}

#Preview { ArrangeRoomsSheet().modelContainer(PreviewStore.seeded(.small)).nookAccent(.terracotta) }
