import SwiftUI
import SwiftData
import NookKit
import NookUI

/// R-04 Warranties (F4): ending in 30 days, active, expired. Swipe to turn an item's
/// reminders off or on. Each item shows the warranty that ends last (D50).
struct WarrantiesScreen: View {
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]
    @State private var toast: ToastMessage?
    @State private var flow: AddFlow?
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }

    /// Add a Warranty: choose an item (or a new one), then its editor at the warranty.
    private enum AddFlow: Identifiable {
        case choose, edit(Item?)
        var id: String {
            switch self {
            case .choose: "choose"
            case .edit(let item): item?.id.uuidString ?? "new"
            }
        }
    }

    private typealias Row = (item: Item, warranty: Warranty, end: Date)

    private var groups: [(SearchFilter.WarrantyStatus, Text, [Row])] {
        let rows = items.compactMap { item -> Row? in
            guard let warranty = item.primaryWarranty, let end = warranty.endDate else { return nil }
            return (item, warranty, end)
        }
        let now = Date.now
        func status(_ row: Row) -> SearchFilter.WarrantyStatus { SearchFilter.status(of: row.end, now: now) }
        return [
            (.ending, Text("Ending in 30 days"), rows.filter { status($0) == .ending }.sorted { $0.end < $1.end }),
            (.active, Text("Active"), rows.filter { status($0) == .active }.sorted { $0.end < $1.end }),
            (.expired, Text("Expired"), rows.filter { status($0) == .expired }.sorted { $0.end > $1.end }),
        ].filter { !$0.2.isEmpty }
    }

    var body: some View {
        let groups = groups
        Group {
            if groups.isEmpty {
                ScrollView {
                    EmptyStateView(.receiptRibbon, title: Text("No warranties yet."),
                                   message: Text("Add one to any item and we’ll remind you before it ends.")) {
                        Button { flow = .choose } label: {
                            Label("Add a Warranty", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.nookPrimary)
                    }
                    .padding(NookSpace.s2)
                    .frame(maxWidth: NookLayout.readableWidth)
                    .frame(maxWidth: .infinity)
                }
            } else {
                List {
                    ForEach(groups, id: \.0) { _, title, rows in
                        Section {
                            ForEach(rows, id: \.warranty.id) { row in
                                warrantyRow(row)
                            }
                        } header: {
                            title.font(.nookSection).foregroundStyle(NookColor.textPrimary).textCase(nil)
                                .accessibilityAddTraits(.isHeader)
                        }
                        .listRowBackground(NookColor.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(NookColor.canvas)
        .navigationTitle("Warranties")
        .toolbarTitleDisplayMode(.large)
        .sheet(item: $flow) { flow in
            switch flow {
            case .choose:
                ItemChooser(title: Text("Add a Warranty"), offersNewItem: true, include: { $0.primaryWarranty == nil }) { item in
                    Task { self.flow = .edit(item) }   // after the chooser closes
                }
            case .edit(let item):
                ItemEditor(item: item, startsAtWarranty: true)
            }
        }
        .toast($toast)
    }

    private func warrantyRow(_ row: Row) -> some View {
        let days = Warranties.daysLeft(until: row.end, now: .now)
        let date = row.end.formatted(.dateTime.month(.abbreviated).day().year())
        let detail = days < 0 ? Text("Ended \(date)") : Text("Ends \(date)")
        let isExpired = days < 0
        return NavigationLink(value: row.item) {
            StoredImage(fileName: row.item.isPrivate ? nil : row.item.cover?.fileName) { image in
                ItemRow(name: row.item.isPrivate ? String(localized: "Private item") : row.item.name,
                        detail: detail, photo: image) {
                    if isExpired {
                        StatusPill(.expired, Text("Expired"))
                    } else if days <= SearchFilter.endingDays {
                        StatusPill(.endingSoon, days == 0 ? Text("Today") : Text("\(days) days"))
                    } else {
                        StatusPill(.active, Text("\(days) days"))
                    }
                    if !isExpired && !row.warranty.remindersOn {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(NookColor.textSecondary)
                            .accessibilityLabel(Text("Reminders off"))
                    }
                }
            }
        }
        .swipeActions {
            if !isExpired { reminderButton(row.warranty).tint(NookColor.textSecondary) }
        }
        .contextMenu {
            if !isExpired { reminderButton(row.warranty) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if !isExpired { reminderButton(row.warranty) }
        }
    }

    private func reminderButton(_ warranty: Warranty) -> some View {
        Button(warranty.remindersOn ? "Reminders Off" : "Reminders On",
               systemImage: warranty.remindersOn ? "bell.slash" : "bell") {
            toast = actions.setReminders(warranty, on: !warranty.remindersOn)
        }
    }
}

#Preview { NavigationStack { WarrantiesScreen() }.modelContainer(PreviewStore.seeded(.lived)) }
#Preview("Empty") { NavigationStack { WarrantiesScreen() }.modelContainer(PreviewStore.seeded(.empty)) }
