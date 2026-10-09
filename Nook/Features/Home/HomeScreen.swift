import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-01 Home: the total value with the Hide values eye (F11), the rooms as cards with the
/// dashed Add room card at the end, warranties ending in the next 30 days (D4), then
/// Recently added.
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
    @Environment(\.dynamicTypeSize) private var typeSize

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
                warrantiesSection
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

    // MARK: Warranties ending soon (H-01, D4)

    @ViewBuilder
    private var warrantiesSection: some View {
        let now = Date.now
        let ending = items.compactMap { item -> (Item, Date)? in
            guard let end = item.primaryWarranty?.endDate, SearchFilter.status(of: end, now: now) == .ending else { return nil }
            return (item, end)
        }
        .sorted { $0.1 < $1.1 }
        if !ending.isEmpty {
            VStack(alignment: .leading, spacing: NookSpace.s1) {
                // Side by side, stacked at accessibility sizes so the title doesn't break.
                let header = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                header {
                    Text("Warranties ending soon")
                        .font(.nookSection)
                        .foregroundStyle(NookColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: NookSpace.s1) }
                    NavigationLink(value: ReportsRoute.warranties) {
                        Text("See All")
                            .font(.nookMeta)
                            .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
                            .contentShape(Rectangle())   // the whole 44 pt target, not just the text
                    }
                    .accessibilityLabel(Text("See all warranties"))
                }
                // A row of cards; a list at accessibility sizes, where they'd be too narrow.
                if typeSize.isAccessibilitySize {
                    VStack(spacing: NookSpace.s1) {
                        ForEach(ending, id: \.0.id) { warrantyCard($0.0, end: $0.1) }
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: NookSpace.s2) {
                            ForEach(ending, id: \.0.id) {
                                warrantyCard($0.0, end: $0.1).frame(width: NookLayout.warrantyCardWidth)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()   // card shadows aren't cut off
                }
            }
        }
    }

    /// "Dishwasher" over "Ends in 12 days". Private items stay unnamed (D46).
    private func warrantyCard(_ item: Item, end: Date) -> some View {
        let days = Warranties.daysLeft(until: end, now: .now)
        let name = item.isPrivate ? String(localized: "Private item") : item.name
        let when = days == 0 ? Text("Ends today") : Text("Ends in \(days) days")
        return NavigationLink(value: item) {
            HStack(spacing: NookSpace.s2) {
                StoredImage(fileName: item.isPrivate ? nil : item.cover?.fileName) { NookPhotoThumb(image: $0) }
                VStack(alignment: .leading, spacing: NookSpace.half) {
                    Text(verbatim: name)
                        .font(.nookHeadline)
                        .foregroundStyle(NookColor.textPrimary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    Label { when } icon: { Image(systemName: "clock") }
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.warning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(NookSpace.s1)
            .nookCard(elevation: .flat)
        }
        .buttonStyle(.nookCard)
        .itemZoomSource(item)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(days == 0 ? Text("\(name), warranty ends today") : Text("\(name), warranty ends in \(days) days"))
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
