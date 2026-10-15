import SwiftUI
import SwiftData
import NookKit
import NookAI
import NookUI

/// R-02 Insurance report: what to include and the cover (F9), then Preview. With an item,
/// it's that item's proof pack: the same report with its receipts (D4, D56).
struct InsuranceReportScreen: View {
    var item: Item?
    @Query(sort: [SortDescriptor(\Room.order), SortDescriptor(\Room.createdAt)]) private var rooms: [Room]
    @AppStorage(PreferenceKey.reportHomeName) private var homeName = ""
    @AppStorage(PreferenceKey.reportInsurer) private var insurer = ""
    @AppStorage(PreferenceKey.reportPolicyNumber) private var policyNumber = ""
    @Environment(\.modelContext) private var context
    @State private var choosesRooms = false
    @State private var chosen: Set<UUID> = []
    @State private var options = ReportOptions()
    @State private var summarizes = false
    @State private var summaries: [UUID: String] = [:]
    @State private var suggested: [UUID: String] = [:]
    @State private var asking: Set<UUID> = []
    @State private var renderer: ReportRenderer?
    @State private var previewing = false

    private var canSummarize: Bool { item == nil && NookAI.status != .unavailable && NookAI.status != .off }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                if item == nil { roomsSection }
                includeSection
                if summarizes, canSummarize { summariesSection }
                coverSection
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(NookColor.canvas)
        .safeAreaInset(edge: .bottom) {
            Button(action: preview) {
                Label("Preview Report", systemImage: "doc.text.magnifyingglass").frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
            .disabled(choosesRooms && chosen.isEmpty)
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
            .background(NookColor.canvas)
        }
        .navigationTitle(item == nil ? "Insurance report" : "Proof pack")
        .toolbarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $previewing) {
            if let renderer { ReportPreviewScreen(renderer: renderer) }
        }
        .onChange(of: summarizes) { _, on in if on { askForSummaries() } }
        .onChange(of: chosen) { if summarizes { askForSummaries() } }
    }

    // MARK: Sections

    private var roomsSection: some View {
        section("Rooms") {
            Picker("Rooms", selection: $choosesRooms) {
                Text("Whole home").tag(false)
                Text("Choose rooms").tag(true)
            }
            .pickerStyle(.segmented)
            if choosesRooms {
                rows {
                    ForEach(rooms) { room in
                        Button { toggle(room.id) } label: {
                            HStack {
                                Text(room.name).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                                Spacer(minLength: NookSpace.s1)
                                if chosen.contains(room.id) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: NookLayout.minTapTarget)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen.contains(room.id) ? .isSelected : [])
                        .hoverEffect(.highlight)
                    }
                }
            }
        }
    }

    private var includeSection: some View {
        section("Include") {
            rows {
                Toggle("Photos", isOn: $options.photos).frame(minHeight: NookLayout.minTapTarget)
                Toggle("Serial numbers", isOn: $options.serials).frame(minHeight: NookLayout.minTapTarget)
                Toggle("Receipts at the end", isOn: $options.receipts).frame(minHeight: NookLayout.minTapTarget)
                if canSummarize {
                    Toggle(isOn: $summarizes) {
                        VStack(alignment: .leading, spacing: NookSpace.half) {
                            Text("Room summaries").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                            Text("A short paragraph per room. You can edit it.")
                                .font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: NookLayout.minTapTarget)
                }
            }
            .font(.nookBody)
            .foregroundStyle(NookColor.textPrimary)
        }
    }

    /// One editable paragraph per room: suggested by the router, or written by hand (D56).
    private var summariesSection: some View {
        section("Room summaries") {
            ForEach(summaryRooms) { room in
                VStack(alignment: .leading, spacing: NookSpace.half) {
                    HStack(spacing: NookSpace.s1) {
                        Text(room.name).font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                        if let text = summaries[room.id], !text.isEmpty, text == suggested[room.id] { SuggestedLabel() }
                    }
                    TextField(asking.contains(room.id) ? "Writing a summary…" : "Add a sentence about this room, or leave it empty.",
                              text: Binding { summaries[room.id] ?? "" } set: { summaries[room.id] = $0 }, axis: .vertical)
                        .font(.nookBody)
                        .lineLimit(2...6)
                        .padding(NookSpace.s2)
                        .background(NookColor.surfaceSunken, in: .rect(cornerRadius: NookRadius.medium))
                        .accessibilityLabel(Text("Summary for \(room.name)"))
                }
            }
        }
    }

    private var coverSection: some View {
        section("On the cover") {
            NookTextField(Text("Home name"), text: $homeName, prompt: Text("Maple Street"))
            NookTextField(Text("Insurer"), text: $insurer, prompt: Text("Optional"))
            NookTextField(Text("Policy number"), text: $policyNumber, prompt: Text("Optional"))
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Text(title).font(.nookMeta).foregroundStyle(NookColor.textSecondary).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func rows(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, NookSpace.s2)
            .padding(.vertical, NookSpace.half)
            .nookCard(elevation: .flat)
    }

    // MARK: Actions

    private var scope: ReportOptions.Scope {
        if let item { return .item(item.id) }
        return choosesRooms ? .rooms(chosen) : .home
    }

    private var summaryRooms: [Room] {
        let live = rooms.filter { RoomService(context: context).liveItemCount(in: $0) > 0 }
        return choosesRooms ? live.filter { chosen.contains($0.id) } : live
    }

    private func toggle(_ id: UUID) {
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
    }

    /// Asks once per room; a paragraph the user has typed is never replaced.
    private func askForSummaries() {
        guard let report = try? ReportSnapshot.make(ReportOptions(scope: scope), context: context, homeCurrency: HomeCurrency.code)
        else { return }
        for section in report.sections {
            guard let id = section.id, suggested[id] == nil, !asking.contains(id), (summaries[id] ?? "").isEmpty else { continue }
            let facts = RoomFacts(room: section.name,
                                  things: section.lines.map { .init(name: $0.name, quantity: $0.quantity) },
                                  totals: section.totals.map { ($0.amount, $0.currencyCode) })
            asking.insert(id)
            Task {
                let text = await NookAI.router.summarizeRoom(facts)
                asking.remove(id)
                guard let text, (summaries[id] ?? "").isEmpty else { return }
                suggested[id] = text
                summaries[id] = text
            }
        }
    }

    private func preview() {
        let options = ReportOptions(scope: scope, photos: options.photos, serials: options.serials, receipts: options.receipts)
        guard let report = try? ReportSnapshot.make(options, context: context, homeCurrency: HomeCurrency.code) else { return }
        let home = homeName.trimmingCharacters(in: .whitespaces)
        let title = item.map { String(localized: "\($0.name) · Proof of ownership") }
            ?? (home.isEmpty ? String(localized: "Home inventory") : String(localized: "\(home) · Home inventory"))
        let kept = summarizes && canSummarize
            ? summaries.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.value.isEmpty } : [:]
        renderer = ReportRenderer(report: report,
                                  cover: ReportCover(title: title, insurer: insurer, policyNumber: policyNumber, date: .now),
                                  options: options, summaries: kept)
        previewing = true
    }
}

#if DEBUG
#Preview("Builder") {
    NavigationStack { InsuranceReportScreen() }
        .modelContainer(PreviewStore.seeded(.lived))
        .nookAccent(.terracotta)
}
#endif

/// I-01's Export Proof Pack (D4): R-02 for one item, in a sheet.
struct ProofPackSheet: View {
    let item: Item
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            InsuranceReportScreen(item: item)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }
                    }
                }
        }
    }
}
