import SwiftUI
import SwiftData
import NookKit
import NookUI

/// R-05 Lent out (F7): who has what, since when and when it's due, overdue first. Swipe to
/// Mark Returned, with Undo.
struct LentOutScreen: View {
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]
    @State private var toast: ToastMessage?
    @State private var flow: LendFlow?
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }

    /// Lend Something: choose an item, then the Lend sheet (I-06).
    private enum LendFlow: Identifiable {
        case choose, lend(Item)
        var id: String {
            switch self {
            case .choose: "choose"
            case .lend(let item): item.id.uuidString
            }
        }
    }

    private var rows: [(item: Item, loan: Loan)] {
        let today = Calendar.current.startOfDay(for: .now)
        return items.compactMap { item in item.activeLoan.map { (item, $0) } }
            .sorted { a, b in
                // Overdue first, then the soonest due, then those with no date, oldest first.
                let (dueA, dueB) = (a.loan.dueAt ?? .distantFuture, b.loan.dueAt ?? .distantFuture)
                let (lateA, lateB) = (dueA < today, dueB < today)
                if lateA != lateB { return lateA }
                return dueA != dueB ? dueA < dueB : a.loan.lentAt < b.loan.lentAt
            }
    }

    var body: some View {
        let rows = rows
        Group {
            if rows.isEmpty {
                ScrollView {
                    EmptyStateView(.boxHands, title: Text("Nothing’s out right now."),
                                   message: Text("When you lend something, it shows up here with a due date.")) {
                        Button { flow = .choose } label: {
                            Text("Lend Something").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.nookPrimary)
                    }
                    .padding(NookSpace.s2)
                    .frame(maxWidth: NookLayout.readableWidth)
                    .frame(maxWidth: .infinity)
                }
            } else {
                List {
                    ForEach(rows, id: \.loan.id) { row in
                        loanRow(row.item, row.loan)
                    }
                    .listRowBackground(NookColor.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(NookColor.canvas)
        .navigationTitle("Lent out")
        .toolbarTitleDisplayMode(.large)
        .sheet(item: $flow) { flow in
            switch flow {
            case .choose:
                ItemChooser(title: Text("Lend Something"), include: { $0.activeLoan == nil }) { item in
                    if let item { Task { self.flow = .lend(item) } }   // after the chooser closes
                }
            case .lend(let item):
                LendSheet(item: item) { toast = $0 }
            }
        }
        .toast($toast)
    }

    private func loanRow(_ item: Item, _ loan: Loan) -> some View {
        let since = loan.lentAt.formatted(.dateTime.month(.abbreviated).day())
        let name = item.isPrivate ? String(localized: "Private item") : item.name
        return NavigationLink(value: item) {
            StoredImage(fileName: item.isPrivate ? nil : item.cover?.fileName) { image in
                ItemRow(name: name, detail: Text("\(loan.personName) · since \(since)"), photo: image) {
                    if let due = loan.dueAt {
                        let late = -Warranties.daysLeft(until: due, now: .now)
                        if late > 0 {
                            StatusPill(.expired, late == 1 ? Text("1 day late") : Text("\(late) days late"))
                        } else {
                            StatusPill(.lent, Text("Due \(due.formatted(.dateTime.month(.abbreviated).day()))"))
                        }
                    }
                }
            }
        }
        .swipeActions {
            Button("Mark Returned", systemImage: "checkmark") { toast = actions.markReturned(loan) }
                .tint(NookColor.success)
        }
        .contextMenu {
            Button("Mark Returned", systemImage: "checkmark") { toast = actions.markReturned(loan) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Mark Returned")) { toast = actions.markReturned(loan) }
    }
}

#Preview { NavigationStack { LentOutScreen() }.modelContainer(PreviewStore.seeded(.lived)) }
#Preview("Empty") { NavigationStack { LentOutScreen() }.modelContainer(PreviewStore.seeded(.empty)) }
