import SwiftUI
import SwiftData
import NookKit
import NookUI

/// R-03 Export CSV: every item and field (F9), shared or saved to Files.
struct CSVExportSheet: View {
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]
    @Environment(EntitlementStore.self) private var entitlements
    @State private var paywall: PaywallRequest?
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var saving = false
    @State private var toast: ToastMessage?

    /// Home's room order, then name.
    private var ordered: [Item] {
        items.sorted { ($0.room?.order ?? .max, $0.name.localizedLowercase) < ($1.room?.order ?? .max, $1.name.localizedLowercase) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s2) {
                    Text("\(items.count) items · \(CSVExport.columns.count) columns · all fields")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    preview
                    Text("Opens in Numbers, Excel and Google Sheets. Prices keep each item’s own currency.")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    actions
                }
                .padding(NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(NookColor.canvas)
            .navigationTitle("Export CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .toast($toast)
            .paywall($paywall)
        }
        .presentationDetents([.medium, .large])
        .task { file = write() }
    }

    /// The first rows, as on the board: name, room and price.
    private var preview: some View {
        Grid(alignment: .leading, horizontalSpacing: NookSpace.s2, verticalSpacing: NookSpace.s1) {
            GridRow {
                Text("Name"); Text("Room"); Text("Price").gridColumnAlignment(.trailing)
            }
            .font(.nookFootnote.weight(.semibold))
            .foregroundStyle(NookColor.textSecondary)
            ForEach(ordered.prefix(3)) { item in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text(item.name).lineLimit(1)
                    Text(item.room?.name ?? "").lineLimit(1)
                    Text(item.price.map(CSVExport.plain) ?? "").monospacedDigit()
                }
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textPrimary)
            }
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard(radius: NookRadius.medium, elevation: .flat)
        // One element that reads the rows; the table itself is a glimpse, cut to fit.
        .accessibilityHidden(true)
        .overlay { Color.clear.accessibilityElement().accessibilityLabel(Text(previewDescription)) }
    }

    /// "Preview of the first rows: Espresso machine, Kitchen, 649.00; …".
    private var previewDescription: String {
        let rows = ordered.prefix(3).map { item in
            [item.name, item.room?.name ?? "", item.price.map(CSVExport.plain) ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
        }
        return String(localized: "Preview of the first rows: \(rows.joined(separator: "; "))")
    }

    @ViewBuilder
    private var actions: some View {
        if !entitlements.canExport {
            // Unlocking shows Share and Save to Files here at once (D58).
            Button { paywall = PaywallRequest(reason: .export) } label: {
                Label("Unlock Pro to Export", systemImage: "lock.open").frame(maxWidth: .infinity)
            }
                .buttonStyle(.nookPrimary)
        } else if let file {
            ShareLink(item: file) {
                Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
            Button { saving = true } label: {
                Label("Save to Files", systemImage: "folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookSecondary)
            .fileMover(isPresented: $saving, file: file) { result in
                if case .success = result {
                    toast = ToastMessage(symbol: "folder", "Saved to Files.")
                    self.file = write()   // the file moved; keep one ready to share again
                }
            }
        }
    }

    /// "Nook items Oct 13, 2026.csv" in the temporary folder.
    private func write() -> URL? {
        let name = String(localized: "Nook items \(Date.now.formatted(date: .abbreviated, time: .omitted))")
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name).csv")
        let csv = CSVExport.csv(ordered, homeCurrency: HomeCurrency.code)
        do {
            try Data(csv.utf8).write(to: url, options: .atomic)
            return url
        } catch {
            toast = ToastMessage(symbol: "exclamationmark.triangle", "The file couldn’t be made. Try again in a moment.")
            return nil
        }
    }
}
