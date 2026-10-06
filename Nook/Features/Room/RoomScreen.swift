import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-02 Room: a header in the room's color, then each spot as a section with its containers.
/// Items fill the sections from P3; "Scan this room" arrives with capture in P6.
struct RoomScreen: View {
    let room: Room
    @State private var editing = false
    @Environment(\.modelContext) private var context

    private var rooms: RoomService { RoomService(context: context) }
    private var color: RoomColor { RoomColor(rawValue: room.colorKey) ?? .stone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                header
                let spots = rooms.spots(in: room)
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
                        SpotSection(spot: spot, containers: rooms.containers(in: spot))
                    }
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
        .background(NookColor.canvas)
        .captureButton()   // D32: Room shows Capture
        .navigationTitle(room.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { editing = true }
            }
        }
        .sheet(isPresented: $editing) { RoomEditor(room: room) }
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
                Text("\(rooms.spots(in: room).count) spots")
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

/// One spot in a room: its name, and its containers as "box" rows.
private struct SpotSection: View {
    let spot: Spot
    let containers: [Spot]

    var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Text(verbatim: spot.name)
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if containers.isEmpty {
                Text("Empty")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(containers) { box in
                        Label { Text(verbatim: box.name) } icon: { Image(systemName: "shippingbox") }
                            .font(.nookBody)
                            .foregroundStyle(NookColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: NookLayout.rowHeight, alignment: .leading)
                            .padding(.horizontal, NookSpace.s2)
                        if box.id != containers.last?.id { Divider() }
                    }
                }
                .nookCard(elevation: .flat)
            }
        }
    }
}
