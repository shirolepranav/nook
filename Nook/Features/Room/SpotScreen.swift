import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-03 Spot / container: where it is, what's inside. A container moves with everything in
/// it (Move Container). The QR label (H-06) arrives in P10.
struct SpotScreen: View {
    let spot: Spot
    @State private var editing = false
    @State private var addingContainer = false
    @State private var addsItem = false
    @State private var viewsPhoto = false
    @State private var selection: Set<UUID>?
    @State private var toast: ToastMessage?
    @State private var moving = false
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    private var rooms: RoomService { RoomService(context: context) }
    private var spotItems: [Item] { ItemService(context: context).items(in: spot) }
    private var location: Location? { spot.room.map { Location(room: $0, spot: spot) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                breadcrumb
                if spot.isContainer, let packedAt = spot.packedAt {
                    Label { Text("Packed on \(packedAt, format: .dateTime.day().month().year())") } icon: {
                        Image(systemName: "shippingbox")
                    }
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                }
                if let photo = spot.photo {
                    Button { viewsPhoto = true } label: {
                        StoredImage(fileName: photo.fileName) { NookPhotoThumb(image: $0) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Spot photo: \(spot.name)"))
                }
                let items = spotItems
                if items.isEmpty {
                    EmptyStateView(.drawerEmpty, title: Text("Nothing here yet."),
                                   message: Text(spot.isContainer ? "Things you put in this container will show up here."
                                                                  : "Things you put on this spot will show up here.")) {
                        Button { addsItem = true } label: {
                            Label("Add Item Here", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.nookPrimary)
                    }
                } else {
                    ItemGrid(items: items, selection: $selection, toast: $toast)
                }
                if !spot.isContainer {
                    containersSection
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.maxGridWidth)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
        .background(NookColor.canvas)
        .captureButton(isShown: selection == nil, at: location)   // D32
        .itemSelection($selection, among: spotItems, toast: $toast)
        .navigationTitle(spot.name)   // itemSelection's title, inside it, wins while selecting
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            if selection == nil {   // I-08 has its own bar while selecting
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item Here", systemImage: "plus") { addsItem = true }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Edit", systemImage: "pencil") { editing = true }
                }
                if spot.isContainer {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Move Container", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                            moving = true
                        }
                    }
                }
            }
        }
        .quickAdd(isPresented: $addsItem, at: location)
        .fullScreenCover(isPresented: $viewsPhoto) {
            if let photo = spot.photo { SpotPhotoViewer(fileName: photo.fileName) }
        }
        .toast($toast)
        .sheet(isPresented: $editing) {
            if let room = spot.room { SpotEditor(room: room, spot: spot) }
        }
        .sheet(isPresented: $moving) {
            MovePicker(title: Text("Move \(spot.name)"), current: spot.room.map { Location(room: $0, spot: spot.parent) },
                       allowsContainers: false) { place in
                if let place { move(to: place) }
            }
        }
        .sheet(isPresented: $addingContainer) {
            if let room = spot.room { SpotEditor(room: room, kind: .container, inside: spot) }
        }
    }

    /// Moves the container and its items, as one Undo step (F6, D44).
    private func move(to place: Location) {
        do {
            try LocationService(context: context).move(spot, to: place)
            undoManager?.setActionName(String(localized: "Move"))
            try context.save()
            toast = ToastMessage(symbol: "arrow.up.and.down.and.arrow.left.and.right",
                                 "Moved \(spot.name) to \(place.path).") { [undoManager, context] in
                undoManager?.undo()
                try? context.save()
            }
        } catch {
            toast = ToastMessage(symbol: "exclamationmark.circle", "Couldn’t move \(spot.name). Your items are safe.")
        }
    }

    /// "Kitchen → Pantry": where this is (03 §8.4). Read as "Kitchen, Pantry".
    private var breadcrumb: some View {
        let path = [spot.room?.name, spot.parent?.name].compactMap { $0 }
        return Text(verbatim: path.joined(separator: " → "))
            .font(.nookMeta)
            .foregroundStyle(RoomColor(rawValue: spot.room?.colorKey ?? "")?.ink ?? NookColor.textSecondary)
            .accessibilityLabel(Text(verbatim: path.joined(separator: ", ")))
    }

    private var containersSection: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Text("Containers")
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(rooms.containers(in: spot)) { box in
                    NavigationLink(value: box) {
                        ContainerRow(container: box)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
                Button { addingContainer = true } label: {
                    Label("Add container", systemImage: "plus")
                        .font(.nookBody)
                        .frame(maxWidth: .infinity, minHeight: NookLayout.rowHeight, alignment: .leading)
                        .padding(.horizontal, NookSpace.s2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .nookCard(elevation: .flat)
        }
    }
}

/// A container as a "box" row (H-02, H-03).
struct ContainerRow: View {
    let container: Spot

    var body: some View {
        HStack(spacing: NookSpace.s2) {
            Image(systemName: "shippingbox")
                .foregroundStyle(NookColor.textSecondary)
                .accessibilityHidden(true)
            Text(verbatim: container.name)
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textSecondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: NookLayout.rowHeight)
        .padding(.horizontal, NookSpace.s2)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)   // D29
    }
}
