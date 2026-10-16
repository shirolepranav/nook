import SwiftUI
import SwiftData
import NookKit
import NookUI

/// S-10 Tags: each tag with its item count. Swipe (or the context menu) to rename, merge or
/// delete; deleting a tag never deletes items. Categories are the fixed list (D53).
struct TagsScreen: View {
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var renaming: String?
    @State private var newName = ""
    @State private var merging: String?
    @State private var toast: ToastMessage?

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }
    private var tags: [(name: String, count: Int)] { ItemService.tagCounts(in: items) }

    var body: some View {
        let tags = tags
        List {
            Section {
                if tags.isEmpty {
                    Text("No tags yet. Add one to an item to group things like “camping” or “wedding gift”.")
                        .font(.nookBody)
                        .foregroundStyle(NookColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(tags, id: \.name) { tag in
                        // By value: a destination closure inside S-01's path-based stack re-rendered
                        // this screen without end once the tag's items were showing.
                        NavigationLink(value: TagRoute(name: tag.name)) { row(tag) }
                            .swipeActions(edge: .trailing) { tagActions(tag.name, others: tags.count > 1) }
                            .contextMenu { tagActions(tag.name, others: tags.count > 1) }
                    }
                }
            } header: {
                header("Your tags")
            } footer: {
                if !tags.isEmpty {
                    Text("Swipe a tag to rename, merge or delete it. Deleting a tag never deletes items.")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                }
            }
            .listRowBackground(NookColor.surface)
            Section {
                Text(verbatim: CommonItems.categories.formatted(.list(type: .and, width: .narrow)))
                    .font(.nookBody)
                    .foregroundStyle(NookColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                header("Categories")
            } footer: {
                Text("Categories are a fixed list, so reports group the same way on every iPhone.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .listRowBackground(NookColor.surface)
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Tags")
        .toolbarTitleDisplayMode(.large)
        .navigationDestination(for: TagRoute.self) { TagItemsScreen(tag: $0.name) }
        // Items open I-01 from here. Not on S-01's root: there, it re-rendered Settings without end.
        .itemNavigation()
        // `presenting` hands the tag to the actions: the dismissal clears `renaming` first.
        .alert("Rename Tag", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
               presenting: renaming) { old in
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                // Renaming onto another tag's name is a merge.
                let merging = tags.contains { $0.name.localizedCaseInsensitiveCompare(newName) == .orderedSame }
                toast = actions.renameTag(old, to: newName, merging: merging)
            }
        }
        .sheet(item: Binding(get: { merging.map(TagChoice.init) }, set: { merging = $0?.name })) { choice in
            MergeTagSheet(tag: choice.name, others: tags.map(\.name).filter { $0 != choice.name }) { target in
                toast = actions.renameTag(choice.name, to: target, merging: true)
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func tagActions(_ tag: String, others: Bool) -> some View {
        // Delete reads as destructive, Merge carries the accent, Rename stays quiet.
        Button("Delete", systemImage: "trash", role: .destructive) { toast = actions.deleteTag(tag) }
            .tint(NookColor.danger)
        if others {
            Button("Merge", systemImage: "arrow.triangle.merge") { merging = tag }
        }
        Button("Rename", systemImage: "pencil") {
            newName = tag
            renaming = tag
        }
        .tint(NookColor.textSecondary)
    }

    /// "coffee · 4", stacked at accessibility sizes like S-01's rows (D61).
    private func row(_ tag: (name: String, count: Int)) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.half))
            : AnyLayout(HStackLayout(spacing: NookSpace.s2))
        return layout {
            HStack(spacing: NookSpace.s2) {
                SettingsIcon(symbol: "tag")
                Text(verbatim: tag.name).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: NookSpace.s1) }
            Text("^[\(tag.count) item](inflect: true)").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
        }
        .frame(minHeight: NookLayout.minTapTarget)
        .accessibilityElement(children: .combine)
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
    }
}

private struct TagRoute: Hashable {
    let name: String
}

private struct TagChoice: Identifiable {
    let name: String
    var id: String { name }
}

/// "Merge coffee into…": the other tags; picking one moves every item over.
private struct MergeTagSheet: View {
    let tag: String
    let others: [String]
    let merge: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(others, id: \.self) { other in
                Button {
                    merge(other)
                    dismiss()
                } label: {
                    Label { Text(verbatim: other) } icon: { Image(systemName: "tag") }
                        .font(.nookBody)
                        .frame(minHeight: NookLayout.minTapTarget)
                }
                .listRowBackground(NookColor.surface)
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .navigationTitle(Text("Merge \(tag) into…"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            }
        }
        .presentationSizing(.form)   // D45: a form sheet on regular width
    }
}

/// A tag's items, as Find shows them. Private items stay masked (D61).
private struct TagItemsScreen: View {
    let tag: String
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }, sort: \Item.name) private var items: [Item]
    @State private var toast: ToastMessage?

    var body: some View {
        let tagged = items.filter { $0.tags.contains { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame } }
        ScrollView {
            ItemGrid(items: tagged, toast: $toast).padding(NookSpace.s2)
        }
        .background(NookColor.canvas)
        .navigationTitle(Text(verbatim: tag))
        .toast($toast)
    }
}

#if DEBUG
#Preview { NavigationStack { TagsScreen() }.modelContainer(PreviewStore.seeded(.lived)).environment(AppLock.preview) }
#endif
