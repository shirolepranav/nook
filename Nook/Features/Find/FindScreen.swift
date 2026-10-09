import SwiftUI
import SwiftData
import NookKit
import NookUI

/// F-01 Find: one field for searching and asking (PRD §6). Before typing it shows saved
/// searches, quick filters and recent searches; while typing, the answer card (F-03) and
/// instant results (F-02). Classic only in P5: questions are read by `FindQuestion` and
/// answered from records by `FindService`; the AI path joins in P9.
struct FindScreen: View {
    @Environment(\.searchLibrary) private var library
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(RecentSearches.key) private var recentText = ""

    @State private var query = ""
    @State private var filter = SearchFilter()
    @State private var found = Found()
    @State private var path = NavigationPath()
    @State private var editsFilters = false
    @State private var savesAfterFilters = false
    @State private var moving: Moving?
    @State private var addsItem = false
    @State private var naming: Naming?
    @State private var name = ""
    @State private var selection: Set<UUID>?
    @State private var toast: ToastMessage?
    @State private var moves = 0   // plays the success haptic (03 §10)

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }
    /// F-03 on regular width: results on the left, the answer beside them (D28, iPadFind board).
    private var answerBeside: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(NookColor.canvas)
                // On compact width the search field sits at the bottom, where Capture would go;
                // the iPhone Find boards leave Capture out, the iPad board keeps it (D32).
                .captureButton(isShown: sizeClass == .regular)
                .navigationTitle("Find")
                .toolbarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { editsFilters = true } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease")
                        }
                        .badge(filter.count)
                        .accessibilityValue(filter.isEmpty ? Text("None") : Text("\(filter.count) on"))
                    }
                }
                .itemSelection($selection, among: found.items, toast: $toast)
                .itemNavigation()
        }
        // Regular width: the field stays open under the title, as on the iPad boards; iOS
        // would otherwise shrink it to a button in narrow iPad windows. Compact: the system's
        // search tab keeps it at the bottom of the screen (D32).
        .searchable(text: $query,
                    placement: sizeClass == .regular ? .navigationBarDrawer(displayMode: .always) : .automatic,
                    prompt: Text("Search or ask: Where are the passports?"))
        .onSubmit(of: .search) { RecentSearches.add(query, to: &recentText) }
        .task(id: SearchKey(query: query, filter: filter, version: library?.version ?? 0)) { await search() }
        // The name prompt waits until the sheet has gone: an alert asked for while the sheet
        // is still closing is dropped, and Save Search would silently do nothing.
        .sheet(isPresented: $editsFilters, onDismiss: {
            guard savesAfterFilters else { return }
            savesAfterFilters = false
            (naming, name) = (.save, query)
        }) {
            FiltersSheet(filter: $filter) { savesAfterFilters = true }
        }
        .sheet(item: $moving) { moving in
            MovePicker(title: moving.source == .found ? Text("Where did you find it?") : Text("Move \(moving.item.name)"),
                       current: Location(of: moving.item)) { place in
                guard let place else { return }
                withNookAnimation(.settle, reduceMotion: reduceMotion) {
                    if let message = actions.move([moving.item], to: place, source: moving.source) {
                        toast = message
                        moves += 1
                    }
                }
            }
        }
        .quickAdd(isPresented: $addsItem, name: query.trimmingCharacters(in: .whitespacesAndNewlines))
        .alert(naming == .save ? Text("Save this search") : Text("Rename search"),
               isPresented: Binding { naming != nil } set: { if !$0 { naming = nil } }) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button(naming == .save ? "Save" : "Rename") { finishNaming() }
        }
        .nookHaptic(.saved, trigger: moves)
        .toast($toast)
    }

    // MARK: Layout

    @ViewBuilder
    private var content: some View {
        if let library, library.isReady, library.itemCount == 0, !found.searched {
            ScrollView {
                EmptyStateView(.drawerEmpty, title: Text("Nothing to find yet."),
                               message: Text("Add a few things and Nook will tell you where they are."))
                    .padding(NookSpace.s2)
                    .frame(maxWidth: NookLayout.readableWidth)
                    .frame(maxWidth: .infinity)
            }
        } else if answerBeside, let answer = answerView {
            HStack(alignment: .top, spacing: 0) {
                list(answer: nil)
                ScrollView { answer.padding(NookSpace.s2) }
                    .frame(maxWidth: NookLayout.readableWidth)
                    .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
            }
        } else {
            list(answer: answerView)
        }
    }

    private func list(answer: AnswerView?) -> some View {
        List {
            if found.searched {
                FindResultsSections(query: query, found: found, answer: answer, filter: $filter, selection: $selection,
                                    open: open, move: { moving = Moving(item: $0, source: .manual) },
                                    add: { addsItem = true }, showFilters: { editsFilters = true })
            } else {
                FindStartSections(query: $query, filter: $filter, recentText: $recentText,
                                  rename: { naming = .rename($0); name = $0.name },
                                  showFilters: { editsFilters = true })
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, sizeClass == .regular ? NookLayout.captureButtonSize + NookSpace.s2 : 0,
                        for: .scrollContent)
        .frame(maxWidth: NookLayout.readableWidth)
        .frame(maxWidth: .infinity)
    }

    private var answerView: AnswerView? {
        guard let answer = found.answer else { return nil }
        let item = answer.itemID.flatMap { id in found.items.first { $0.id == id } }
        var place: Location?
        if case .contents(let id, _, _) = answer {
            place = found.places.first { ($0.spot?.id ?? $0.room.id) == id }
        }
        guard item != nil || place != nil else { return nil }
        return AnswerView(answer: answer, item: item, place: place,
                          actions: AnswerActions(move: { moving = Moving(item: $0, source: $1) }, open: open,
                                                 returned: markReturned))
    }

    // MARK: Actions

    private func markReturned(_ item: Item) {
        if let loan = item.activeLoan { toast = actions.markReturned(loan) }
    }

    private func open(_ value: any Hashable) {
        RecentSearches.add(query, to: &recentText)
        path.append(value)
    }

    private func search() async {
        guard let library else { return }
        let question = FindQuestion(query)
        guard !question.terms.isEmpty || !filter.isEmpty else {
            found = Found()
            return
        }
        let hits = await library.search(question, filter: filter)
        guard !Task.isCancelled else { return }
        let find = FindService(context: context)
        let next = Found(searched: true,
                         answer: question.terms.isEmpty ? nil : find.answer(question, hits: hits),
                         items: find.items(matching: hits),
                         places: find.places(matching: hits))
        withNookAnimation(.fade, reduceMotion: reduceMotion) { found = next }   // 03 §9: results cross-fade
    }

    private func finishNaming() {
        let find = FindService(context: context)
        switch naming {
        case .save:
            find.save(name: name, query: query, filter: filter)
            toast = ToastMessage(symbol: "pin", "Saved to Find.")
        case .rename(let saved):
            find.rename(saved, to: name)
        case nil:
            break
        }
        try? context.save()
        naming = nil
    }
}

/// What the last search found. `searched` is false before typing (or choosing a filter).
struct Found {
    var searched = false
    var answer: FindAnswer?
    var items: [Item] = []
    var places: [Location] = []
}

private struct SearchKey: Hashable {
    let query: String
    let filter: SearchFilter
    let version: Int
}

private struct Moving: Identifiable {
    let item: Item
    let source: LocationEvent.Source
    var id: UUID { item.id }
}

private enum Naming: Equatable {
    case save
    case rename(SavedSearch)
}

/// The last 5 searches, newest first, kept on this device only (D46).
enum RecentSearches {
    static let key = "recentSearches"
    static let limit = 5

    static func list(_ text: String) -> [String] {
        text.split(separator: "\n").map(String.init)
    }

    static func add(_ query: String, to text: inout String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let others = list(text).filter { $0.localizedCaseInsensitiveCompare(query) != .orderedSame }
        text = ([query] + others).prefix(limit).joined(separator: "\n")
    }
}

#if DEBUG
/// Previews build a real index from a seeded store, as the shell does.
private struct FindPreview: View {
    let container = PreviewStore.seeded(.lived)
    @State private var library: SearchLibrary?

    var body: some View {
        FindScreen()
            .modelContainer(container)
            .environment(\.searchLibrary, library)
            .task {
                let library = SearchLibrary(container: container)
                self.library = library
                await library.keepCurrent()
            }
            .nookAccent(.terracotta)
    }
}

#Preview("Find") { FindPreview() }
#Preview("Dark") { FindPreview().preferredColorScheme(.dark) }
#Preview("AX5") { FindPreview().dynamicTypeSize(.accessibility5) }
#Preview("Empty") {
    FindScreen().modelContainer(PreviewStore.seeded(.empty)).nookAccent(.terracotta)
}
#endif
