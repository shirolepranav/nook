import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-02 Room: a header in the room's color, the items placed straight in the room, then each
/// spot as a section with its items and containers. "Scan this room" arrives in P6.
struct RoomScreen: View {
    let room: Room
    @State private var editing = false
    @State private var adding: Spot.Kind?
    @State private var arranging = false
    @State private var addsItem = false
    @State private var selection: Set<UUID>?
    @State private var toast: ToastMessage?
    @Environment(\.modelContext) private var context

    private var rooms: RoomService { RoomService(context: context) }
    private var items: ItemService { ItemService(context: context) }
    private var color: RoomColor { RoomColor(rawValue: room.colorKey) ?? .stone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                header
                let spots = rooms.spots(in: room)
                ItemSection(items: items.looseItems(in: room), selection: $selection, toast: $toast) {
                    sectionTitle("In this room")
                }
                if spots.isEmpty {
                    EmptyStateView(.kitchenEmpty, title: Text("Nothing here yet."),
                                   message: Text("Add the spots in this room, like shelves, drawers and cupboards.")) {
                        Button { editing = true } label: {
                            Label("Add Spots", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.nookPrimary)
                    }
                } else {
                    ForEach(spots) { spot in
                        SpotSection(spot: spot, items: items.items(in: spot), containers: rooms.containers(in: spot),
                                    selection: $selection, toast: $toast)
                    }
                }
                let loose = rooms.looseContainers(in: room)
                if !loose.isEmpty {
                    // D34: containers sitting on the room itself.
                    VStack(alignment: .leading, spacing: NookSpace.s1) {
                        sectionTitle("Containers")
                        ContainerList(containers: loose)
                    }
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.maxGridWidth)   // item grids use the width (D29)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
        .background(NookColor.canvas)
        .captureButton(isShown: selection == nil, at: Location(room: room))   // D32: Room shows Capture
        .itemSelection($selection, among: shownItems, toast: $toast)
        .navigationTitle(room.name)   // itemSelection's title, inside it, wins while selecting
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Add", systemImage: "plus") {
                    Button("Add Item", systemImage: "plus.square") { addsItem = true }
                    Button("Add Spot", systemImage: "square.stack") { adding = .spot }
                    Button("Add Container", systemImage: "shippingbox") { adding = .container }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Edit Room", systemImage: "pencil") { editing = true }
            }
            if rooms.spots(in: room).count > 1 {
                ToolbarItem(placement: .secondaryAction) {
                    // H-02: drag to reorder spots
                    Button("Arrange Spots", systemImage: "arrow.up.arrow.down") { arranging = true }
                }
            }
        }
        .sheet(isPresented: $editing) { RoomEditor(room: room) }
        .sheet(item: $adding) { SpotEditor(room: room, kind: $0) }
        .sheet(isPresented: $arranging) { ArrangeSheet.spots(in: room) }
        .quickAdd(isPresented: $addsItem, at: Location(room: room))
        .navigationDestination(for: Spot.self) { SpotScreen(spot: $0) }
        .toast($toast)
    }

    /// The items on this screen: loose ones and those on spots (container items live on the
    /// container's screen).
    private var shownItems: [Item] {
        items.looseItems(in: room) + rooms.spots(in: room).flatMap(items.items(in:))
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.nookSection)
            .foregroundStyle(NookColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var header: some View {
        HStack(spacing: NookSpace.s2) {
            Image(systemName: room.symbol)
                .font(.nookTitle)
                .foregroundStyle(color.ink)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: room.name)
                    .font(.nookTitle)
                    .foregroundStyle(NookColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("\(items.allItems(in: room).count) items · \(rooms.spots(in: room).count) spots")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(NookSpace.s2)
        .background(color.fill, in: RoundedRectangle(cornerRadius: NookRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// One spot in a room: its name (opens the spot, H-03), its items, and its containers as
/// "box" rows.
private struct SpotSection: View {
    let spot: Spot
    let items: [Item]
    let containers: [Spot]
    @Binding var selection: Set<UUID>?
    @Binding var toast: ToastMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            NavigationLink(value: spot) {
                HStack {
                    Text(verbatim: spot.name)
                        .font(.nookSection)
                        .foregroundStyle(NookColor.textPrimary)
                    Image(systemName: "chevron.forward")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: NookLayout.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            if !items.isEmpty {
                ItemGrid(items: items, selection: $selection, toast: $toast)
            }
            if !containers.isEmpty {
                ContainerList(containers: containers)
            } else if items.isEmpty {
                Text("Empty")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
        }
    }
}

/// Containers as tappable "box" rows on a paper card.
private struct ContainerList: View {
    let containers: [Spot]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(containers) { box in
                NavigationLink(value: box) { ContainerRow(container: box) }
                    .buttonStyle(.plain)
                if box.id != containers.last?.id { Divider() }
            }
        }
        .nookCard(elevation: .flat)
    }
}

extension Spot.Kind: @retroactive Identifiable {
    public var id: String { rawValue }
}
