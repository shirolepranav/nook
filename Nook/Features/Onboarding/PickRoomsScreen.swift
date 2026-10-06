import SwiftUI
import NookKit
import NookUI

/// O-02 Pick your rooms: suggested rooms as chips (the first four on), "Add your own" inline,
/// then Continue lands on Home (01 §4). Each room gets its color and symbol automatically.
struct PickRoomsScreen: View {
    /// The rooms to create, in the order shown.
    let finish: ([String]) -> Void

    @State private var picked: [String] = RoomPreset.all.prefix(4).map(\.name)
    @State private var custom: [String] = []
    @State private var isAdding = false
    @State private var newName = ""
    @FocusState private var nameFieldFocused: Bool

    private var options: [String] { RoomPreset.all.map(\.name) + custom }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                VStack(alignment: .leading, spacing: NookSpace.s1) {
                    Text("Which rooms do you have?")
                        .font(.nookDisplay)
                        .foregroundStyle(NookColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a few to start. You can change them any time.")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                }
                NookFlowLayout {
                    ForEach(options, id: \.self) { name in
                        let style = RoomPreset.style(for: name, existingColorKeys: [])
                        RoomChip(name: name, symbol: style.symbol,
                                 color: RoomColor(rawValue: style.colorKey) ?? .stone,
                                 isSelected: picked.contains(name)) { toggle(name) }
                    }
                    if !isAdding {
                        Button {
                            isAdding = true
                            nameFieldFocused = true
                        } label: {
                            Label("Add your own", systemImage: "plus")
                        }
                        .buttonStyle(.nookSecondary)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Rooms"))
                if isAdding {
                    NookTextField(Text("Room name"), text: $newName, prompt: Text("Studio"))
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addCustom)
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button { finish(options.filter(picked.contains)) } label: {
                Text(picked.isEmpty ? "Continue without rooms" : "Continue with \(picked.count) rooms")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
        }
        .background(NookColor.canvas)
    }

    private func toggle(_ name: String) {
        if let index = picked.firstIndex(of: name) {
            picked.remove(at: index)
        } else {
            picked.append(name)
        }
    }

    private func addCustom() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            newName = ""
            isAdding = false
        }
        guard !name.isEmpty else { return }
        if let existing = options.first(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            if !picked.contains(existing) { picked.append(existing) }   // typed a suggestion: just pick it
            return
        }
        custom.append(name)
        picked.append(name)
    }
}

#Preview { PickRoomsScreen { _ in }.nookAccent(.terracotta) }
