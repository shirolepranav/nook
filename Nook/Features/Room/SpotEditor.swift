import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-05 Spot / container editor: type, name, and for a container where it sits (the room, or
/// one of its spots; never another container, D34). Nothing is written until Save.
struct SpotEditor: View {
    let room: Room
    /// nil for a new one.
    let spot: Spot?

    @State private var kind: Spot.Kind
    @State private var name: String
    @State private var insideID: UUID?
    @State private var isPacked: Bool
    @State private var packedAt: Date
    @State private var confirmsDelete = false
    @State private var failure: LocalizedStringResource?
    @FocusState private var nameFocused: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(room: Room, spot: Spot? = nil, kind: Spot.Kind = .spot, inside: Spot? = nil) {
        self.room = room
        self.spot = spot
        _kind = State(initialValue: spot?.kind ?? kind)
        _name = State(initialValue: spot?.name ?? "")
        _insideID = State(initialValue: spot?.parent?.id ?? inside?.id)
        _isPacked = State(initialValue: spot?.packedAt != nil)
        _packedAt = State(initialValue: spot?.packedAt ?? .now)
    }

    private var rooms: RoomService { RoomService(context: context) }
    /// Where a container can go: the spots in this room, except itself.
    private var places: [Spot] { rooms.spots(in: room).filter { $0.id != spot?.id } }
    private var holdsContainers: Bool { !(spot?.children ?? []).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Spot").tag(Spot.Kind.spot)
                        Text("Container").tag(Spot.Kind.container)
                    }
                    .pickerStyle(.segmented)
                    .disabled(holdsContainers)   // D34: it holds containers, so it stays a spot
                    .nookHaptic(.selected, trigger: kind)
                    TextField("Name", text: $name, prompt: Text(kind == .spot ? "Top shelf" : "Blue bin"))
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                } footer: {
                    if holdsContainers {
                        Text("It holds containers, so it stays a spot.")
                    }
                }
                .listRowBackground(NookColor.surface)   // paper rows, not system gray (03 §6)
                if kind == .container {
                    Section {
                        Picker("Inside", selection: $insideID) {
                            Text(verbatim: room.name).tag(UUID?.none)
                            ForEach(places) { place in
                                Text(verbatim: "\(room.name) → \(place.name)").tag(Optional(place.id))
                            }
                        }
                        Toggle("Packed", isOn: $isPacked.animation())
                        if isPacked {
                            DatePicker("Packed on", selection: $packedAt, displayedComponents: .date)
                        }
                    } footer: {
                        Text("A container sits in a room or a spot. It can’t go inside another container.")
                    }
                    .listRowBackground(NookColor.surface)
                }
                if spot != nil {
                    Section {
                        Button(kind == .spot ? "Delete Spot" : "Delete Container", role: .destructive) {
                            confirmsDelete = true
                        }
                    }
                    .listRowBackground(NookColor.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .environment(\.defaultMinListRowHeight, NookLayout.rowHeight)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(Text("Delete \(spot?.name ?? "")?"), isPresented: $confirmsDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text(holdsContainers ? "The containers in it are deleted too." : "You can undo right after.")
            }
            .alert(Text(failure ?? ""), isPresented: Binding { failure != nil } set: { if !$0 { failure = nil } }) {
                Button("OK") {}
            }
        }
        .presentationSizing(.form)
        .onAppear { if spot == nil { nameFocused = true } }
    }

    private var title: LocalizedStringKey {
        switch (spot == nil, kind) {
        case (true, .spot): "New Spot"
        case (true, .container): "New Container"
        case (false, .spot): "Edit Spot"
        case (false, .container): "Edit Container"
        }
    }

    private func save() {
        let inside = places.first { $0.id == insideID }
        do {
            let saved: Spot
            if let spot {
                try rooms.rename(spot, to: name)
                try rooms.setKind(of: spot, to: kind)
                if kind == .container { try rooms.place(spot, inside: inside) }
                saved = spot
            } else if kind == .spot {
                saved = try rooms.addSpot(named: name, in: room)
            } else {
                saved = try rooms.addContainer(named: name, in: room, inside: inside)
            }
            saved.packedAt = kind == .container && isPacked ? packedAt : nil
            try context.save()
            dismiss()
        } catch {
            failure = "Couldn’t save this. Try again."
        }
    }

    private func delete() {
        guard let spot else { return }
        do {
            try rooms.delete(spot)
            try context.save()
            dismiss()
        } catch {
            failure = "Move the things in it somewhere else first."   // P3 adds the choice (D28)
        }
    }
}
