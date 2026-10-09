import SwiftUI
import SwiftData
import NookKit
import NookUI

/// Picks one item for an action that starts from a list rather than an item: Add a Warranty
/// (R-04) and Lend Something (R-05), so their empty states have an action (01 §1.3).
/// Private items aren't offered, since their names stay hidden (D46).
struct ItemChooser: View {
    let title: Text
    var offersNewItem = false
    let include: (Item) -> Bool
    let choose: (Item?) -> Void   // nil: "New Item"

    @Query(filter: #Predicate<Item> { $0.deletedAt == nil && !$0.isPrivate }, sort: \Item.name)
    private var items: [Item]
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var shown: [Item] {
        let words = query.trimmingCharacters(in: .whitespaces)
        return items.filter { include($0) && (words.isEmpty || $0.name.localizedStandardContains(words)) }
    }

    var body: some View {
        NavigationStack {
            List {
                if offersNewItem {
                    Button { pick(nil) } label: {
                        Label("New Item", systemImage: "plus")
                            .frame(minHeight: NookLayout.rowHeight)
                    }
                    .listRowBackground(NookColor.surface)
                }
                ForEach(shown) { item in
                    Button { pick(item) } label: {
                        StoredImage(fileName: item.cover?.fileName) { image in
                            ItemRow(name: item.name, detail: item.placeText, photo: image)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(NookColor.surface)
                    .accessibilityElement(children: .combine)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .overlay {
                if shown.isEmpty && !offersNewItem {
                    ContentUnavailableView(query.isEmpty ? "Nothing to choose yet." : "No matches.",
                                           systemImage: "shippingbox")
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search items"))
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationSizing(.form)
    }

    private func pick(_ item: Item?) {
        choose(item)
        dismiss()
    }
}
