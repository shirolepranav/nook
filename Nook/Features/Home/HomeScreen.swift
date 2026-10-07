import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-01 Home: the total value with the Hide values eye (F11), the rooms as cards with the
/// dashed Add room card at the end, then Recently added. "Warranties ending soon" joins in P7.
struct HomeScreen: View {
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }, sort: \Item.createdAt, order: .reverse)
    private var items: [Item]
    @AppStorage(PreferenceKey.hideValues) private var hideValues = false
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
                if items.isEmpty {
                    Text("\(rooms.count) rooms, ready to fill")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                } else {
                    totalValue
                }
                roomsSection
                ItemSection(items: Array(items.prefix(Self.recentCount)), toast: $toast) {
                    Text("Recently added")
                        .font(.nookSection)
                        .foregroundStyle(NookColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
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
            if let deleting {
                let rooms = RoomService(context: context)
                RehomeChoices(itemCount: rooms.liveItemCount(in: deleting), destinations: rooms.destinations(leaving: deleting),
                              deleteTitle: "Delete Room") { delete(deleting, $0) }
            }
        } message: {
            if let deleting, RoomService(context: context).liveItemCount(in: deleting) > 0 {
                Text("It holds \(RoomService(context: context).liveItemCount(in: deleting)) items. Where should they go? You can undo right after.")
            } else {
                Text("Its spots and containers are deleted too. You can undo right after.")
            }
        }
        .sheet(isPresented: $arranging) { ArrangeSheet.rooms }
        .toast($toast)
    }

    private static let recentCount = 6

    /// D20, D41: the total in the home currency; other currencies are never converted.
    private var totalValue: some View {
        let code = HomeCurrency.code
        let priced = items.compactMap(\.value)
        let total = priced.filter { $0.currencyCode == code }.reduce(Decimal(0)) { $0 + $1.amount }
        let mixed = priced.contains { $0.currencyCode != code }
        return HStack(alignment: .center, spacing: NookSpace.s1) {
            VStack(alignment: .leading, spacing: 0) {
                MoneyText(total, currencyCode: code, font: .nookTotal)
                    .foregroundStyle(NookColor.textPrimary)
                Text(mixed ? "\(items.count) items · Mixed currencies" : "\(items.count) items")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button(hideValues ? "Show Values" : "Hide Values",
                   systemImage: hideValues ? "eye.slash" : "eye") { hideValues.toggle() }
                .labelStyle(.iconOnly)
                .font(.nookSection)
                .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
                .nookHaptic(.selected, trigger: hideValues)
        }
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
    }

    private func itemCount(_ room: Room) -> Int {
        let items = (room.items ?? []) + (room.spots ?? []).flatMap { $0.items ?? [] }
        return Set(items.filter { $0.deletedAt == nil }.map(\.id)).count
    }

    private func delete(_ room: Room, _ rehoming: RoomService.Rehoming?) {
        let name = room.name
        do {
            try RoomService(context: context).delete(room, rehoming: rehoming)
            try context.save()
            showDeleted(name)
        } catch {
            toast = ToastMessage(symbol: "exclamationmark.circle", "Couldn’t delete \(name). Your items are safe.")
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
