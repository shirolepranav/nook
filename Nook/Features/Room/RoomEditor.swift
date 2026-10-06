import SwiftUI
import SwiftData
import NookKit
import NookUI

/// H-04 Room editor, for a new room or an existing one: name, symbol, color, and its spots
/// with "Add spot" right here so a room with 3 spots takes under 30 seconds (F1, D28).
/// Nothing is written until Save; Cancel leaves the room as it was.
struct RoomEditor: View {
    /// nil for a new room.
    let room: Room?
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var symbol: String
    @State private var colorKey: String
    @State private var newSpots: [String] = []
    @State private var draftSpot = ""
    @State private var isAddingSpot = false
    @State private var confirmsDelete = false
    @State private var failure: String?
    @FocusState private var focus: Field?
    @Environment(\.dynamicTypeSize) private var typeSize

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private enum Field { case name, spot }

    init(room: Room?, onDelete: (() -> Void)? = nil) {
        self.room = room
        self.onDelete = onDelete
        _name = State(initialValue: room?.name ?? "")
        _symbol = State(initialValue: room?.symbol ?? "square.grid.2x2")
        _colorKey = State(initialValue: room?.colorKey ?? "")
    }

    private var rooms: RoomService { RoomService(context: context) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s3) {
                    NookTextField(Text("Name"), text: $name, prompt: Text("Kitchen"))
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit(startSpot)
                    symbolPicker
                    colorPicker
                    spotsSection
                    if room != nil {
                        Button(role: .destructive) { confirmsDelete = true } label: {
                            Label("Delete Room", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.nookDestructive)
                    }
                }
                .padding(NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(NookColor.canvas)
            .navigationTitle(room == nil ? "New Room" : "Edit Room")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .confirmationDialog(Text("Delete \(room?.name ?? "")?"), isPresented: $confirmsDelete,
                                titleVisibility: .visible) {
                if let room {
                    RehomeChoices(itemCount: rooms.liveItemCount(in: room), destinations: rooms.destinations(leaving: room),
                                  deleteTitle: "Delete Room", delete: delete)
                }
            } message: {
                if let room, rooms.liveItemCount(in: room) > 0 {
                    Text("It holds \(rooms.liveItemCount(in: room)) items. Where should they go? You can undo right after.")
                } else {
                    Text("Its spots and containers are deleted too. You can undo right after.")
                }
            }
            .alert(Text(failure ?? ""), isPresented: Binding { failure != nil } set: { if !$0 { failure = nil } }) {
                Button("OK") {}
            }
        }
        .presentationSizing(.form)   // a centered form sheet on regular width (D29)
        .onAppear {
            if colorKey.isEmpty {
                colorKey = RoomPreset.style(for: "", existingColorKeys: (try? rooms.rooms())?.map(\.colorKey) ?? []).colorKey
            }
            if room == nil { focus = .name }
        }
        .onChange(of: name) { old, new in
            // A preset name brings its symbol and color, unless the user already chose them.
            guard room == nil else { return }
            let style = RoomPreset.style(for: new, existingColorKeys: [])
            if RoomPreset.all.contains(where: { $0.name.localizedCaseInsensitiveCompare(new) == .orderedSame }) {
                symbol = style.symbol
                colorKey = style.colorKey
            }
        }
    }

    // MARK: Sections

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            label("Symbol")
            // 3 columns at accessibility sizes: 6 can't hold the larger symbols.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NookSpace.s1),
                                     count: typeSize.isAccessibilitySize ? 3 : 6),
                      spacing: NookSpace.s1) {
                ForEach(Self.symbols, id: \.self) { candidate in
                    let isOn = candidate == symbol
                    Button { symbol = candidate } label: {
                        Image(systemName: candidate)
                            .font(.nookSection)
                            .frame(maxWidth: .infinity, minHeight: NookLayout.minTapTarget)
                            .foregroundStyle(isOn ? roomColor.ink : NookColor.textSecondary)
                            .background(isOn ? roomColor.fill : NookColor.surfaceSunken,
                                        in: RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(Self.symbolNames[candidate] ?? candidate)))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .nookHaptic(.selected, trigger: symbol)
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            label("Color")
            HStack(spacing: NookSpace.s1) {
                ForEach(RoomColor.allCases) { color in
                    let isOn = color.rawValue == colorKey
                    Button { colorKey = color.rawValue } label: {
                        Circle()
                            .fill(color.fill)
                            .overlay { if isOn { Image(systemName: "checkmark").foregroundStyle(color.ink) } }
                            .overlay { Circle().strokeBorder(isOn ? color.ink : NookColor.hairline, lineWidth: isOn ? 2 : 1) }
                            .frame(maxWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(color.title))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .nookHaptic(.selected, trigger: colorKey)
        }
    }

    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            label("Spots")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(existingSpots) { spot in
                    spotRow(Text(verbatim: spot.name))
                    Divider()
                }
                ForEach(newSpots, id: \.self) { spot in
                    spotRow(Text(verbatim: spot))
                    Divider()
                }
                if isAddingSpot {
                    // Vertical axis: Return types a newline instead of resigning the field, so
                    // it stays open for the next spot (F1: 3 spots fast). Finished lines become
                    // rows once typing pauses: rewriting the text mid-typing drops or reorders
                    // keystrokes (D35).
                    TextField("Spot name", text: $draftSpot, prompt: Text("Top shelf"), axis: .vertical)
                        .accessibilityLabel("Spot name")   // iOS 27 reads only the prompt otherwise
                        .font(.nookBody)
                        .focused($focus, equals: .spot)
                        .submitLabel(.next)
                        .task(id: draftSpot) {
                            guard draftSpot.contains("\n"),
                                  (try? await Task.sleep(for: .seconds(0.5))) != nil else { return }
                            let text = draftSpot
                            guard let newline = text.lastIndex(of: "\n") else { return }
                            text[..<newline].split(separator: "\n").forEach { appendSpot(String($0)) }
                            draftSpot = String(text[text.index(after: newline)...])
                        }
                        .frame(minHeight: NookLayout.rowHeight)
                        .padding(.horizontal, NookSpace.s2)
                    Divider()
                }
                Button(action: startSpot) {
                    Label("Add spot", systemImage: "plus")
                        .font(.nookBody)
                        .frame(maxWidth: .infinity, minHeight: NookLayout.rowHeight, alignment: .leading)
                        .padding(.horizontal, NookSpace.s2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .nookCard(elevation: .flat)   // grouped rows: paper, no shadow
        }
    }

    private func spotRow(_ title: Text) -> some View {
        title
            .font(.nookBody)
            .foregroundStyle(NookColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: NookLayout.rowHeight, alignment: .leading)
            .padding(.horizontal, NookSpace.s2)
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.nookFootnote.weight(.semibold))
            .foregroundStyle(NookColor.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Actions

    private var roomColor: RoomColor { RoomColor(rawValue: colorKey) ?? .stone }
    private var existingSpots: [Spot] { room.map(rooms.spots(in:)) ?? [] }

    private func startSpot() {
        addDraftSpot()
        isAddingSpot = true
        focus = .spot
    }

    private func addDraftSpot() {
        draftSpot.split(separator: "\n").forEach { appendSpot(String($0)) }   // lines not split yet
        draftSpot = ""
    }

    private func appendSpot(_ name: String) {
        let spot = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !spot.isEmpty { newSpots.append(spot) }
    }

    private func save() {
        addDraftSpot()
        do {
            let saved: Room
            if let room {
                try rooms.rename(room, to: name)
                room.symbol = symbol
                room.colorKey = colorKey
                saved = room
            } else {
                saved = try rooms.addRoom(named: name, symbol: symbol, colorKey: colorKey)
            }
            for spot in newSpots { try rooms.addSpot(named: spot, in: saved) }
            try context.save()
            dismiss()
        } catch {
            failure = String(localized: "Couldn’t save this room. Try again.")
        }
    }

    private func delete(_ rehoming: RoomService.Rehoming?) {
        guard let room else { return }
        do {
            try rooms.delete(room, rehoming: rehoming)
            try context.save()
            dismiss()
            onDelete?()
        } catch {
            failure = String(localized: "Couldn’t delete this room. Your items are safe.")
        }
    }

    // MARK: Symbols

    /// The preset rooms' symbols (the board's 6×2 grid).
    static let symbols = RoomPreset.all.map(\.symbol).reduce(into: [String]()) { list, s in
        if !list.contains(s) { list.append(s) }
    }

    /// VoiceOver names for the symbols: the room they stand for.
    static let symbolNames: [String: String] = Dictionary(
        RoomPreset.all.map { ($0.symbol, $0.name) }, uniquingKeysWith: { first, _ in first })
}

#Preview("New") { RoomEditor(room: nil).modelContainer(PreviewStore.seeded(.small)).nookAccent(.terracotta) }
