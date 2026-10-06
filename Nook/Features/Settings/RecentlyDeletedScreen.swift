import SwiftUI
import SwiftData
import NookKit
import NookUI

/// S-08 Recently Deleted: what was deleted in the last 30 days (D14), with Restore. Delete
/// Now and Delete All Now are final, so they ask first (D40).
struct RecentlyDeletedScreen: View {
    @Query(filter: #Predicate<Item> { $0.deletedAt != nil }, sort: \Item.deletedAt, order: .reverse)
    private var items: [Item]
    @State private var deletingNow: [Item] = []
    @State private var toast: ToastMessage?
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }

    var body: some View {
        Group {
            if items.isEmpty {
                ScrollView {
                    EmptyStateView(.binEmpty, title: Text("Nothing deleted."),
                                   message: Text("Items you delete wait here for 30 days, in case you change your mind."))
                        .padding(NookSpace.s2)
                        .frame(maxWidth: NookLayout.readableWidth)
                        .frame(maxWidth: .infinity)
                }
            } else {
                list
            }
        }
        .background(NookColor.canvas)
        .navigationTitle("Recently Deleted")
        .toolbarTitleDisplayMode(.large)
        .confirmationDialog(confirmTitle, isPresented: Binding { !deletingNow.isEmpty } set: { if !$0 { deletingNow = [] } },
                            titleVisibility: .visible) {
            Button(deletingNow.count == 1 ? "Delete Now" : "Delete All Now", role: .destructive) {
                ItemService(context: context).deleteNow(deletingNow)
                try? context.save()
                deletingNow = []
            }
        } message: {
            Text("This can’t be undone.")
        }
        .toast($toast)
    }

    private var confirmTitle: Text {
        deletingNow.count == 1
            ? Text("Delete \(deletingNow.first?.name ?? "") now?")
            : Text("Delete \(deletingNow.count) items now?")
    }

    private var list: some View {
        let service = ItemService(context: context)
        return List {
            Section {
                ForEach(items) { item in
                    StoredImage(fileName: item.cover?.fileName) { image in
                        ItemRow(name: item.name, detail: Text("\(service.daysLeft(item)) days left"), photo: image) {
                            Button("Restore") { toast = actions.restore([item]) }
                                .buttonStyle(.nookTertiary)
                                .frame(minHeight: NookLayout.minTapTarget)
                        }
                    }
                    .swipeActions {
                        Button("Delete Now", systemImage: "trash", role: .destructive) { deletingNow = [item] }
                    }
                    .contextMenu {
                        Button("Restore", systemImage: "arrow.uturn.backward") { toast = actions.restore([item]) }
                        Button("Delete Now", systemImage: "trash", role: .destructive) { deletingNow = [item] }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: Text("Restore")) { toast = actions.restore([item]) }
                    .accessibilityAction(named: Text("Delete Now")) { deletingNow = [item] }
                }
            } header: {
                Text("Deleted items stay here for 30 days, then they’re gone for good.")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                    .textCase(nil)
            }
            .listRowBackground(NookColor.surface)
            Section {
                Button(role: .destructive) { deletingNow = items } label: {
                    Text("Delete All Now").frame(maxWidth: .infinity)
                }
                .listRowBackground(NookColor.surfaceSunken)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview { NavigationStack { RecentlyDeletedScreen() }.modelContainer(PreviewStore.seeded(.small)) }
