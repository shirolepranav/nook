import SwiftUI
import SwiftData
import NookKit
import NookUI

/// I-04 Move picker: the last 5 places as one-tap rows, then rooms → spots → containers,
/// with search. It only reports the choice; the caller moves through `LocationService`
/// (CLAUDE.md hard rule). F6: Move → a recent place is 2 taps.
struct MovePicker: View {
    let title: Text
    /// Where the thing is now: shown as "Here now" and not offered.
    let current: Location?
    /// Containers can't go inside containers (D34), so moving one hides them.
    var allowsContainers = true
    /// The item editor can also take an item out of every room.
    var allowsNoRoom = false
    let choose: (Location?) -> Void

    @State private var query = ""
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    let recents = LocationService(context: context).recents(excluding: current)
                        .filter { allowsContainers || $0.spot?.isContainer != true }
                    if !recents.isEmpty {
                        Section("Recent") {
                            ForEach(recents, id: \.self) { place in
                                PlaceRow(place: place, label: Text(verbatim: place.path), isCurrent: false) { pick(place) }
                            }
                        }
                    }
                    Section("All rooms") {
                        ForEach(rooms) { room in
                            NavigationLink(value: room) { RoomRow(room: room) }
                        }
                    }
                } else {
                    let matches = rooms.flatMap(places).filter { $0.path.localizedStandardContains(query) }
                    if matches.isEmpty {
                        Text("No rooms or spots match “\(query)”.")
                            .font(.nookBody)
                            .foregroundStyle(NookColor.textSecondary)
                    }
                    ForEach(matches, id: \.self) { place in
                        PlaceRow(place: place, label: Text(verbatim: place.path), isCurrent: place == current) { pick(place) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search rooms and spots"))
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: Room.self) { room in
                List {
                    ForEach(places(in: room), id: \.self) { place in
                        PlaceRow(place: place, label: label(for: place), isCurrent: place == current,
                                 indented: place.spot?.parent != nil) { pick(place) }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(NookColor.canvas)
                .navigationTitle(Text(verbatim: room.name))
                .toolbarTitleDisplayMode(.inline)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                if allowsNoRoom, current != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("No Room Yet") { choose(nil); dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])   // 03 §8.8: medium height for pickers
        .presentationSizing(.form)                // a centered form sheet on regular width (D29)
    }

    private func pick(_ place: Location) {
        choose(place)
        dismiss()
    }

    /// The room itself, each spot with its containers under it, then containers on the floor.
    private func places(in room: Room) -> [Location] {
        let service = RoomService(context: context)
        var result = [Location(room: room)]
        for spot in service.spots(in: room) {
            result.append(Location(room: room, spot: spot))
            if allowsContainers {
                result += service.containers(in: spot).map { Location(room: room, spot: $0) }
            }
        }
        if allowsContainers {
            result += service.looseContainers(in: room).map { Location(room: room, spot: $0) }
        }
        return result
    }

    private func label(for place: Location) -> Text {
        place.spot.map { Text(verbatim: $0.name) } ?? Text("In the room")
    }
}

/// A room in the picker's list: symbol, name and how many spots it has.
private struct RoomRow: View {
    let room: Room

    var body: some View {
        let spotCount = (room.spots ?? []).filter { !$0.isContainer }.count
        HStack(spacing: NookSpace.s2) {
            PlaceIcon(room: room)
            Text(verbatim: room.name)
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
            Spacer(minLength: 0)
            Text("\(spotCount) spots")
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
        }
        .frame(minHeight: NookLayout.minTapTarget)
        .listRowBackground(NookColor.surface)
    }
}

/// One place to move to. The current place shows "Here now" and can't be picked.
private struct PlaceRow: View {
    let place: Location
    let label: Text
    let isCurrent: Bool
    var indented = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NookSpace.s2) {
                PlaceIcon(room: place.room, container: place.spot?.isContainer == true)
                label
                    .font(.nookBody)
                    .foregroundStyle(NookColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isCurrent {
                    Label("Here now", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                }
            }
            .padding(.leading, indented ? NookSpace.s4 : 0)
            .frame(minHeight: NookLayout.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
        .listRowBackground(NookColor.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: place.names.joined(separator: ", ")))
        .accessibilityValue(isCurrent ? Text("Here now") : Text(verbatim: ""))
        .accessibilityAddTraits(.isButton)
    }
}

/// The room's symbol in its soft color (I-04 mockup); a box for containers.
private struct PlaceIcon: View {
    let room: Room
    var container = false

    var body: some View {
        let color = RoomColor(rawValue: room.colorKey) ?? .stone
        Image(systemName: container ? "shippingbox" : room.symbol)
            .font(.nookMeta)
            .foregroundStyle(color.ink)
            .frame(width: NookLayout.placeIconSize, height: NookLayout.placeIconSize)
            .background(color.fill, in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview {
    Text(verbatim: "Item")
        .sheet(isPresented: .constant(true)) {
            MovePicker(title: Text(verbatim: "Move Espresso machine"), current: nil) { _ in }
        }
        .modelContainer(PreviewStore.seeded(.lived))
}
