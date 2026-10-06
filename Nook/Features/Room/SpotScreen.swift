import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-03 Spot / container: where it is, what's inside. Items join in P3, the QR label (H-06)
/// in P10, "Move container" in P4.
struct SpotScreen: View {
    let spot: Spot
    @State private var editing = false
    @State private var addingContainer = false
    @Environment(\.modelContext) private var context

    private var rooms: RoomService { RoomService(context: context) }

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
                if !spot.isContainer {
                    containersSection
                }
                EmptyStateView(.drawerEmpty, title: Text("Nothing here yet."),
                               message: Text(spot.isContainer ? "Things you put in this container will show up here."
                                                              : "Things you put on this spot will show up here."))
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
        .background(NookColor.canvas)
        .captureButton()   // D32
        .navigationTitle(spot.name)
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            if let room = spot.room { SpotEditor(room: room, spot: spot) }
        }
        .sheet(isPresented: $addingContainer) {
            if let room = spot.room { SpotEditor(room: room, kind: .container, inside: spot) }
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
