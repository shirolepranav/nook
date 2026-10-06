import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-01 Home. P2: the rooms as cards, with the dashed Add room card at the end. Total value,
/// "Warranties ending soon" and "Recently added" join once items exist (P3, P7).
struct HomeScreen: View {
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]
    @State private var editing: EditTarget?
    @State private var deleting: Room?
    @State private var arranging = false
    @State private var toast: ToastMessage?
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    private enum EditTarget: Identifiable {
        case new, room(Room)
        var id: String {
            switch self {
            case .new: "new"
            case .room(let room): room.id.uuidString
            }
        }
    }

    var body: some View {
        TabRoot("Home") {
            if rooms.isEmpty {
                EmptyStateView(.shelfWaiting, title: Text("Let’s start with one room."),
                               message: Text("Add the rooms you have, then fill them in.")) {
                    Button { editing = .new } label: {
                        Label("Add a Room", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.nookPrimary)
                }
            } else {
                Text("\(rooms.count) rooms, ready to fill")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                roomsSection
            }
        }
        .sheet(item: $editing) { target in
            switch target {
            case .new: RoomEditor(room: nil)
            case .room(let room): RoomEditor(room: room) { showDeleted(room.name) }
            }
        }
        .confirmationDialog(Text("Delete \(deleting?.name ?? "")?"),
                            isPresented: Binding { deleting != nil } set: { if !$0 { deleting = nil } },
                            titleVisibility: .visible) {
            Button("Delete Room", role: .destructive) { if let deleting { delete(deleting) } }
        } message: {
            Text("Its spots and containers are deleted too. You can undo right after.")
        }
        .sheet(isPresented: $arranging) { ArrangeRoomsSheet() }
        .toast($toast)
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Text("Rooms")
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            NookGrid {
                ForEach(rooms) { room in
                    NavigationLink(value: room) {
                        RoomCard(name: room.name, symbol: room.symbol,
                                 color: RoomColor(rawValue: room.colorKey) ?? .stone, itemCount: itemCount(room))
                    }
                    .buttonStyle(.nookCard)
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { editing = .room(room) }
                        Button("Change Color and Symbol", systemImage: "paintpalette") { editing = .room(room) }
                        Button("Arrange Rooms", systemImage: "arrow.up.arrow.down") { arranging = true }
                        Button("Delete", systemImage: "trash", role: .destructive) { deleting = room }
                    }
                }
                Button { editing = .new } label: { AddCard(Text("Add room")) }
                    .buttonStyle(.nookCard)
            }
        }
        .navigationDestination(for: Room.self) { RoomScreen(room: $0) }
    }

    private func itemCount(_ room: Room) -> Int {
        let items = (room.items ?? []) + (room.spots ?? []).flatMap { $0.items ?? [] }
        return Set(items.filter { $0.deletedAt == nil }.map(\.id)).count
    }

    private func delete(_ room: Room) {
        let name = room.name
        do {
            try RoomService(context: context).delete(room)
            try context.save()
            showDeleted(name)
        } catch {
            toast = ToastMessage(symbol: "exclamationmark.circle", "Move the things in \(name) somewhere else first.")
        }
    }

    /// D14: an Undo toast after every delete; ⌘Z and shake undo it too (04 §9).
    private func showDeleted(_ name: String) {
        toast = ToastMessage(symbol: "trash", "Deleted \(name).") { [undoManager, context] in
            undoManager?.undo()
            try? context.save()
        }
    }
}

#Preview("Rooms") { HomeScreen().modelContainer(PreviewStore.seeded(.small)).nookAccent(.terracotta) }
#Preview("Empty") { HomeScreen().modelContainer(PreviewStore.seeded(.empty)).nookAccent(.terracotta) }
