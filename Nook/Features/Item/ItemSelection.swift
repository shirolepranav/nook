import SwiftUI
import SwiftData
import NookKit
import NookUI

extension View {
    /// I-08 Multi-select for a screen of items: "N Selected" in the title, Cancel and Select
    /// All, and a bottom bar with Move, Tag, Private and Delete in place of the tab bar.
    /// `selection` is nil while not selecting.
    func itemSelection(_ selection: Binding<Set<UUID>?>, among items: [Item], toast: Binding<ToastMessage?>) -> some View {
        modifier(ItemSelection(selection: selection, items: items, toast: toast))
    }
}

private struct ItemSelection: ViewModifier {
    @Binding var selection: Set<UUID>?
    let items: [Item]
    @Binding var toast: ToastMessage?

    @State private var confirmsDelete = false
    @State private var tagging = false
    @State private var moving = false
    @State private var tag = ""
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }
    private var selected: [Item] { items.filter { selection?.contains($0.id) == true } }

    func body(content: Content) -> some View {
        if selection != nil {
            selecting(content)
        } else {
            content.toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Select", systemImage: "checkmark.circle") { selection = [] }
                    }
                }
            }
        }
    }

    private func selecting(_ content: Content) -> some View {
        let count = selected.count
        let none = count == 0
        return content
            .navigationTitle(Text("\(count) Selected"))
            .navigationBarBackButtonHidden()
            // Only the bar hides; the selected tab never changes (D35).
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selection = nil }
                }
                ToolbarItem(placement: .primaryAction) {
                    if count == items.count {
                        Button("Deselect All") { selection = [] }
                    } else {
                        Button("Select All") { selection = Set(items.map(\.id)) }
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right") { moving = true }
                        .disabled(none)
                    Spacer()
                    Button("Tag", systemImage: "tag") { tag = ""; tagging = true }
                        .disabled(none)
                    Spacer()
                    let allPrivate = !none && selected.allSatisfy(\.isPrivate)
                    Button(allPrivate ? "Not Private" : "Private", systemImage: allPrivate ? "lock.open" : "lock") {
                        toast = actions.setPrivate(selected, !allPrivate)
                    }
                    .disabled(none)
                    Spacer()
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                        .disabled(none)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Actions for \(count) items"))
            .focusedSceneValue(\.itemCommands, none ? nil : ItemCommands(edit: nil, move: { moving = true }, delete: { confirmsDelete = true }))
            .confirmationDialog(Text("Delete \(count) items?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete \(count) Items", role: .destructive) {
                    toast = actions.delete(selected)
                    selection = nil
                }
            } message: {
                Text("You can restore them from Recently Deleted for 30 days.")
            }
            .sheet(isPresented: $moving) {
                let current = Set(selected.map { Location(of: $0) })
                MovePicker(title: count == 1 ? Text("Move \(selected[0].name)") : Text("Move \(count) Items"),
                           current: current.count == 1 ? current.first ?? nil : nil) { place in
                    guard let place else { return }
                    toast = actions.move(selected, to: place)
                    selection = nil
                }
            }
            .alert(Text("Add a tag to \(count) items"), isPresented: $tagging) {
                TextField("Tag", text: $tag)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    ItemService(context: context).addTag(tag, to: selected)
                    try? context.save()
                    toast = ToastMessage(symbol: "tag", "Tagged \(count) items.")
                }
            }
            .onChange(of: items.map(\.id)) { _, ids in
                selection = selection?.intersection(ids)   // items deleted elsewhere drop out
            }
    }
}
