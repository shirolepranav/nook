import SwiftUI
import SwiftData
import NookKit
import NookUI

/// I-05 Location history: every place the item has been, newest first, so "Where did the
/// drill used to be?" has an answer (PRD §6). Paths are the names at the time of the move.
struct LocationHistoryScreen: View {
    let item: Item
    @Environment(\.modelContext) private var context

    var body: some View {
        let events = LocationService(context: context).history(of: item)
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                if let first = events.last {
                    Text("\(item.name) · \(events.count) places since \(first.date, format: .dateTime.month(.abbreviated).year())")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                }
                if events.isEmpty {
                    EmptyStateView(.drawerEmpty, title: Text("No moves yet."),
                                   message: Text("Each time you move it, the place shows up here."))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            HistoryRow(event: event, isLast: index == events.count - 1)
                        }
                    }
                    .padding(NookSpace.s2)
                    .nookCard(elevation: .flat)
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
        .navigationTitle("Location history")
        .toolbarTitleDisplayMode(.inline)
    }
}

/// One stop on the timeline: when, where to, where from, and who moved it.
private struct HistoryRow: View {
    let event: LocationEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: NookSpace.s2) {
            // The rail: a dot per stop, joined by a hairline.
            VStack(spacing: 0) {
                Circle()
                    .fill(.tint)
                    .frame(width: NookLayout.timelineDotSize, height: NookLayout.timelineDotSize)
                    .padding(.top, NookSpace.half)
                if !isLast {
                    Rectangle().fill(NookColor.hairline).frame(width: 1)
                }
            }
            .frame(width: NookLayout.timelineDotSize)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                Text(verbatim: event.toPath.isEmpty ? String(localized: "Taken out of its room") : event.toPath)
                    .font(.nookBody.weight(.semibold))
                    .foregroundStyle(NookColor.textPrimary)
                if !event.fromPath.isEmpty {
                    Text("from \(event.fromPath)")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                }
                sourceText
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, isLast ? 0 : NookSpace.s3)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var sourceText: Text {
        if event.fromPath.isEmpty { return Text("Added") }
        return switch event.source {
        case .manual: Text("Moved by you")
        case .found: Text("Found here by you")
        case .siri: Text("Moved with Siri")
        case .ai: Text("Suggested move, confirmed by you")
        case .qr: Text("Moved by scanning a label")
        }
    }

    /// "Aug 3, 2026. Kitchen, Counter. From Dining room, Sideboard. Moved by you."
    private var accessibilityText: Text {
        let spoken = { (path: String) in path.replacingOccurrences(of: " → ", with: ", ") }
        let date = Text(event.date, format: .dateTime.month(.wide).day().year())
        let place = event.toPath.isEmpty ? Text("Taken out of its room") : Text(verbatim: spoken(event.toPath))
        let from = event.fromPath.isEmpty ? Text(verbatim: "") : Text(" From \(spoken(event.fromPath)).")
        return Text("\(date). \(place).\(from) \(sourceText).")
    }
}
