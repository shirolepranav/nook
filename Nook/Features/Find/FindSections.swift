import SwiftUI
import SwiftData
import NookKit
import NookUI

// MARK: Before typing (F-01, F-06)

/// "Try asking", saved searches (F-06), quick filters and recent searches. Sections with
/// nothing in them are left out, so nothing on Find is a dead end.
struct FindStartSections: View {
    @Binding var query: String
    @Binding var filter: SearchFilter
    @Binding var recentText: String
    let rename: (SavedSearch) -> Void
    let showFilters: () -> Void

    @Environment(\.searchLibrary) private var library
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\SavedSearch.order), SortDescriptor(\SavedSearch.createdAt)])
    private var saved: [SavedSearch]

    var body: some View {
        if let example {
            Section {
                FilterChip(verbatim: example, isSelected: false) { query = example }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            } header: { FindHeader("Try asking") }
        }
        if !saved.isEmpty {
            Section {
                ForEach(saved) { search in
                    Button { (query, filter) = (search.query, search.filter) } label: {
                        HStack {
                            Text(verbatim: search.name).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                            Spacer()
                            if let count = library?.count(FindQuestion(search.query), filter: search.filter) {
                                Text("\(count)").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                            }
                        }
                        .frame(minHeight: NookLayout.minTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .swipeActions {   // D28: swipe to Rename or Delete
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(search) }
                        Button("Rename", systemImage: "pencil") { rename(search) }
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { rename(search) }
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(search) }
                    }
                    .accessibilityAction(named: Text("Rename")) { rename(search) }
                    .accessibilityAction(named: Text("Delete")) { delete(search) }
                }
                .onMove { source, destination in
                    FindService(context: context).move(saved, from: source, to: destination)
                    try? context.save()
                }
                .listRowBackground(NookColor.surface)
            } header: { FindHeader("Saved searches") }
        }
        let quick = quickFilters
        if library?.itemCount ?? 0 > 0 {
            Section {
                NookFlowLayout(spacing: NookSpace.s1) {
                    // Also here, not only in the toolbar: on iPhone the search tab hides the bar
                    // while the field is focused (D47).
                    FiltersChip(action: showFilters)
                    ForEach(quick, id: \.title) { chip in
                        FilterChip(verbatim: chip.title, isSelected: false) { filter = chip.filter }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: { FindHeader("Quick filters") }
        }
        let recents = RecentSearches.list(recentText)
        if !recents.isEmpty {
            Section {
                ForEach(recents, id: \.self) { recent in
                    Button { query = recent } label: {
                        Label { Text(verbatim: recent) } icon: { Image(systemName: "clock.arrow.circlepath") }
                            .font(.nookBody)
                            .foregroundStyle(NookColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: NookLayout.minTapTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                }
                .listRowBackground(NookColor.surface)
            } header: { FindHeader("Recent") }
        }
    }

    /// A question about the user's own latest thing, so trying it always finds an answer.
    private var example: String? {
        library?.exampleName.map { String(localized: "Where’s my \($0)?") }
    }

    private var quickFilters: [(title: String, filter: SearchFilter)] {
        guard let library else { return [] }
        var lent = SearchFilter(); lent.lentOnly = true
        var ending = SearchFilter(); ending.warranty = .ending
        var unseen = SearchFilter(); unseen.lastSeen = .overTwoYears
        // Only chips with something behind them: lending and warranties arrive in P7 (D46).
        return [(lent, String(localized: "Lent out")), (ending, String(localized: "Warranty ending")),
                (unseen, String(localized: "Not seen in 2 years"))]
            .compactMap { filter, name in
                let count = library.count(filter: filter)
                return count > 0 ? (title: "\(name) · \(count)", filter: filter) : nil
            }
    }

    private func delete(_ search: SavedSearch) {
        FindService(context: context).delete(search)
        try? context.save()
    }
}

// MARK: Results (F-02)

/// The answer card, active filters, then Items, Rooms and spots, and Containers. Private
/// items are listed but masked (PRD §9); opening one needs Face ID from P12 (D46).
struct FindResultsSections: View {
    let query: String
    let found: Found
    let answer: AnswerView?
    @Binding var filter: SearchFilter
    @Binding var selection: Set<UUID>?
    let open: (any Hashable) -> Void
    let move: (Item) -> Void
    let add: () -> Void
    let showFilters: () -> Void

    var body: some View {
        if let answer {
            Section {
                answer
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        Section {
            NookFlowLayout(spacing: NookSpace.s1) {
                FiltersChip(action: showFilters)
                ActiveFilterChips(filter: $filter)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        let items = found.items.filter { $0.id != found.answer?.itemID }
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    ResultRow(item: item, selection: $selection, open: open, move: move)
                }
                .listRowBackground(NookColor.surface)
            } header: { FindHeader(found.answer == nil ? "Items" : "Also matching") }
        }
        let rooms = found.places.filter { $0.spot?.isContainer != true }
        if !rooms.isEmpty {
            Section {
                ForEach(rooms, id: \.self) { PlaceRow(place: $0, open: open) }
                    .listRowBackground(NookColor.surface)
            } header: { FindHeader("Rooms and spots") }
        }
        let boxes = found.places.filter { $0.spot?.isContainer == true }
        if !boxes.isEmpty {
            Section {
                ForEach(boxes, id: \.self) { PlaceRow(place: $0, open: open) }
                    .listRowBackground(NookColor.surface)
            } header: { FindHeader("Containers") }
        }
        if found.items.isEmpty && found.places.isEmpty {
            Section { noResults.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
        } else {
            // A footer, not a row: a row's fixed height would stop it growing with Dynamic Type.
            Section {} footer: {
                Text("Also searched receipts, serials and notes.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var noResults: some View {
        let words = FindQuestion(query).terms.joined(separator: " ")
        if words.isEmpty {
            EmptyStateView(.drawerEmpty, title: Text("Nothing matches these filters."),
                           message: Text("Try removing one.")) {
                Button("Clear Filters") { filter = SearchFilter() }.buttonStyle(.nookSecondary)
            }
        } else {
            EmptyStateView(.drawerEmpty, title: Text("Nothing called “\(words)” yet."),
                           message: Text("Check the spelling, or add it now.")) {
                Button("Add “\(words)” as an Item", action: add).buttonStyle(.nookPrimary)
            }
        }
    }
}

/// An item result: photo, name, breadcrumb and Move (F-02). Masked when Private.
private struct ResultRow: View {
    let item: Item
    @Binding var selection: Set<UUID>?
    let open: (any Hashable) -> Void
    let move: (Item) -> Void

    var body: some View {
        let isSelected = selection.map { $0.contains(item.id) }
        HStack(spacing: NookSpace.s1) {
            Button {
                if var chosen = selection {
                    if chosen.remove(item.id) == nil { chosen.insert(item.id) }
                    selection = chosen
                } else {
                    open(item)
                }
            } label: {
                if item.isPrivate {
                    ItemRow(name: String(localized: "Private item"), detail: Text("Unlock to see it"), isSelected: isSelected)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("Private item. Unlock to see it"))
                } else {
                    StoredImage(fileName: item.cover?.fileName) { image in
                        ItemRow(name: item.name, detail: detail, photo: image, isSelected: isSelected)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected == true ? .isSelected : [])
            if selection == nil && !item.isPrivate {
                Button { move(item) } label: {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                }
                .buttonStyle(NookButtonStyle(.secondary, isCompact: true))
                .accessibilityLabel(Text("Move \(item.name)"))
            }
        }
        .accessibilityAction(named: Text("Move")) { if !item.isPrivate { move(item) } }
    }

    private var detail: Text {
        guard let location = Location(of: item) else { return Text("No room yet") }
        return Breadcrumb.text(location.names, color: location.roomColor)
    }

    /// Name, room, the rest of the path, value (03 §11).
    private var label: Text {
        let place = Location(of: item)?.names.joined(separator: ", ") ?? String(localized: "No room yet")
        return Text(verbatim: "\(item.name), \(place)")
    }
}

/// A room, spot or container result.
private struct PlaceRow: View {
    let place: Location
    let open: (any Hashable) -> Void

    var body: some View {
        Button { open(place.spot.map { $0 as any Hashable } ?? place.room) } label: {
            HStack(spacing: NookSpace.s2) {
                Image(systemName: place.spot == nil ? place.room.symbol : place.spot!.isContainer ? "shippingbox" : "square.stack")
                    .foregroundStyle(place.roomColor.ink)
                    .frame(width: NookLayout.placeIconSize, height: NookLayout.placeIconSize)
                    .background(place.roomColor.fill, in: Circle())
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)   // a glyph in a fixed circle
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: place.spot?.name ?? place.room.name)
                        .font(.nookHeadline)
                        .foregroundStyle(NookColor.textPrimary)
                    if place.spot != nil {
                        Breadcrumb.text(Array(place.names.dropLast()), color: place.roomColor)
                            .font(.nookMeta)
                            .foregroundStyle(NookColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: NookLayout.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(Text(verbatim: place.names.joined(separator: ", ")))
    }
}

/// Active filters as removable chips (F-05).
struct ActiveFilterChips: View {
    @Binding var filter: SearchFilter
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]

    var body: some View {
        Group {
            ForEach(rooms.filter { filter.roomIDs.contains($0.id) }) { room in
                chip(room.name) { filter.roomIDs.remove(room.id) }
            }
            if let category = filter.category { chip(category) { filter.category = nil } }
            ForEach(filter.tags.sorted(), id: \.self) { tag in chip(tag) { filter.tags.remove(tag) } }
            if filter.minValue != nil || filter.maxValue != nil {
                chip(valueText) { (filter.minValue, filter.maxValue) = (nil, nil) }
            }
            switch filter.warranty {
            case .any: EmptyView()
            case .active: chip(String(localized: "Warranty active")) { filter.warranty = .any }
            case .ending: chip(String(localized: "Warranty ending")) { filter.warranty = .any }
            case .expired: chip(String(localized: "Warranty expired")) { filter.warranty = .any }
            }
            if filter.lentOnly { chip(String(localized: "Lent out")) { filter.lentOnly = false } }
            switch filter.lastSeen {
            case .any: EmptyView()
            case .overOneYear: chip(String(localized: "Not seen in 1 year")) { filter.lastSeen = .any }
            case .overTwoYears: chip(String(localized: "Not seen in 2 years")) { filter.lastSeen = .any }
            }
        }
    }

    private var valueText: String {
        let style = Decimal.FormatStyle.Currency(code: HomeCurrency.code).precision(.fractionLength(0))
        switch (filter.minValue, filter.maxValue) {
        case let (min?, max?): return "\(min.formatted(style)) – \(max.formatted(style))"
        case let (min?, nil): return String(localized: "From \(min.formatted(style))")
        case let (nil, max?): return String(localized: "Up to \(max.formatted(style))")
        case (nil, nil): return ""
        }
    }

    /// Tapping a chip takes that filter off.
    private func chip(_ title: String, remove: @escaping () -> Void) -> some View {
        FilterChip(verbatim: title, isSelected: true, action: remove)
            .accessibilityLabel(Text("Remove filter: \(title)"))
    }
}

/// Opens F-05.
private struct FiltersChip: View {
    let action: () -> Void

    var body: some View {
        FilterChip("Filters", isSelected: false, action: action)
    }
}

/// A section title in the Find boards' style.
struct FindHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.nookSection)
            .foregroundStyle(NookColor.textPrimary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}
