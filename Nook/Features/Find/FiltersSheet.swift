import SwiftUI
import SwiftData
import NookKit
import NookUI

/// F-05 Filters (F05Filters board): room, last seen, warranty, value, category, tags and
/// lent out. Changes apply with "Show N Items"; "Save Search" applies them and names the
/// search (F-06). Warranty and lending rows show only once there's something to filter
/// (P7 creates them, D46).
struct FiltersSheet: View {
    @Binding var filter: SearchFilter
    let save: () -> Void

    @State private var draft = SearchFilter()
    @Environment(\.searchLibrary) private var library
    @Environment(\.windowSizeClass) private var windowSizeClass
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]

    private var docs: [SearchDoc] { library?.index.docs.filter { $0.kind == .item } ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                if !rooms.isEmpty {
                    Section("Room") {
                        NookFlowLayout(spacing: NookSpace.s1) {
                            ForEach(rooms) { room in
                                RoomChip(name: room.name, symbol: room.symbol,
                                         color: RoomColor(rawValue: room.colorKey) ?? .stone,
                                         isSelected: draft.roomIDs.contains(room.id)) {
                                    if draft.roomIDs.remove(room.id) == nil { draft.roomIDs.insert(room.id) }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                Section("Last seen") {
                    Picker("Last seen", selection: $draft.lastSeen) {
                        Text("Any Time").tag(SearchFilter.LastSeen.any)
                        Text("1 yr+").tag(SearchFilter.LastSeen.overOneYear)
                        Text("2 yrs+").tag(SearchFilter.LastSeen.overTwoYears)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint(Text("Things you haven’t moved or confirmed in that long."))
                }
                if docs.contains(where: { $0.warrantyEnd != nil }) || draft.warranty != .any {
                    Section("Warranty") {
                        Picker("Warranty", selection: $draft.warranty) {
                            Text("Any").tag(SearchFilter.WarrantyStatus.any)
                            Text("Active").tag(SearchFilter.WarrantyStatus.active)
                            Text("Ending").tag(SearchFilter.WarrantyStatus.ending)
                            Text("Expired").tag(SearchFilter.WarrantyStatus.expired)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section {
                    LabeledContent("Value from") {
                        TextField("Any", value: $draft.minValue, format: valueFormat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(Text("Value from"))
                    }
                    LabeledContent("Value to") {
                        TextField("Any", value: $draft.maxValue, format: valueFormat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(Text("Value to"))
                    }
                } header: {
                    Text("Value")
                } footer: {
                    Text("Only items priced in \(HomeCurrency.code).")   // D41: nothing is converted
                }
                if !categories.isEmpty {
                    Section {
                        Picker("Category", selection: $draft.category) {
                            Text("Any").tag(String?.none)
                            ForEach(categories, id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
                        }
                    }
                }
                if !tags.isEmpty {
                    Section("Tags") {
                        NookFlowLayout(spacing: NookSpace.s1) {
                            ForEach(tags, id: \.self) { tag in
                                FilterChip(verbatim: tag, isSelected: draft.tags.contains(tag)) {
                                    if draft.tags.remove(tag) == nil { draft.tags.insert(tag) }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                if docs.contains(where: \.isLent) || draft.lentOnly {
                    Section {
                        Toggle("Lent out only", isOn: $draft.lentOnly)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .navigationTitle("Filters")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                if !draft.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") { draft = SearchFilter() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { buttons }
        }
        .onAppear { draft = filter }
        // 03 §8.8: medium height on iPhone; on regular width a detent would turn the form
        // sheet back into a bottom sheet (D45).
        .presentationDetents(windowSizeClass == .regular ? [.large] : [.medium, .large])
        .presentationSizing(.form)
    }

    private var buttons: some View {
        let count = library?.count(filter: draft) ?? 0
        return HStack(spacing: NookSpace.s1) {
            Button("Save Search") {
                filter = draft
                dismiss()
                save()
            }
            .buttonStyle(.nookSecondary)
            .disabled(draft.isEmpty)
            Button(draft.isEmpty ? "Done" : "Show \(count) Items") {
                filter = draft
                dismiss()
            }
            .buttonStyle(.nookPrimary)
            .frame(maxWidth: .infinity)
        }
        .padding(NookSpace.s2)
        .background(NookColor.canvas)
    }

    private var valueFormat: Decimal.FormatStyle.Currency {
        .currency(code: HomeCurrency.code).precision(.fractionLength(0...2))
    }

    private var categories: [String] {
        Set(docs.map(\.category).filter { !$0.isEmpty }).sorted()
    }

    private var tags: [String] {
        var seen = Set<String>()
        return docs.flatMap(\.tags).filter { seen.insert($0.lowercased()).inserted }.sorted()
    }
}
