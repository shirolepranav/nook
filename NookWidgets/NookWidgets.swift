import SwiftUI
import SwiftData
import WidgetKit
import AppIntents
import NookKit
import NookUI

/// Nook's widgets and controls (F10, 01 §12, W01Widgets and CTL01Controls boards). Widgets
/// read the App Group store, read-only, and never show a Private item (PRD §9).
@main
struct NookWidgets: WidgetBundle {
    var body: some Widget {
        WarrantiesWidget()
        ValueWidget()
        QuickFindWidget()
        ScanRoomControl()
        FindControl()
    }
}

// MARK: Data

struct NookEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// The store couldn't be read (before the first unlock after a restart, PRD §9).
    var isUnavailable = false
}

/// One read-only container for the extension's life.
enum WidgetStore {
    static let container = try? NookStore.makeContainer(readOnly: true)

    /// A fresh context on whatever queue WidgetKit asks from.
    static func snapshot(at date: Date) -> WidgetSnapshot? {
        guard let container else { return nil }
        return try? WidgetSnapshot.read(from: ModelContext(container), now: date, currencyCode: HomeCurrency.code)
    }
}

struct NookProvider: TimelineProvider {
    func placeholder(in context: Context) -> NookEntry { NookEntry(date: .now, snapshot: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (NookEntry) -> Void) {
        // The widget gallery shows sample content, not the user's home.
        if context.isPreview { return completion(placeholder(in: context)) }
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NookEntry>) -> Void) {
        do {
            let now = Date.now
            let calendar = Calendar.current
            let first = entry(at: now)
            guard !first.isUnavailable else {
                // Locked after a restart: try again soon (Data Protection, PRD §9).
                return completion(Timeline(entries: [first], policy: .after(now.addingTimeInterval(15 * 60))))
            }
            // A new entry each midnight for a week, so "12 days" counts down without the app (F4).
            let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now)) }
            let entries = [first] + midnights.map { NookEntry(date: $0, snapshot: first.snapshot) }
            completion(Timeline(entries: entries, policy: .after(midnights.last ?? now.addingTimeInterval(86_400))))
        }
    }

    private func entry(at date: Date) -> NookEntry {
        guard let snapshot = WidgetStore.snapshot(at: date) else {
            return NookEntry(date: date, snapshot: .empty, isUnavailable: true)
        }
        return NookEntry(date: date, snapshot: snapshot)
    }
}

// MARK: Shared look

private extension View {
    /// The paper background, the user's accent and their Hide values setting (S-06, D28).
    func nookWidget() -> some View {
        modifier(NookWidgetStyle())
    }
}

private struct NookWidgetStyle: ViewModifier {
    @AppStorage("accentChoice", store: UserDefaults(suiteName: NookKit.appGroupID))
    private var accent: AccentChoice = .terracotta

    func body(content: Content) -> some View {
        content
            .containerBackground(NookColor.surface, for: .widget)
            .nookAccent(accent)
            .defaultAppStorage(UserDefaults(suiteName: NookKit.appGroupID) ?? .standard)   // MoneyText's Hide values
    }
}

/// Before the first unlock after a restart, nothing can be read.
private struct LockedWidget: View {
    var body: some View {
        VStack(spacing: NookSpace.s1) {
            Image(systemName: "lock").font(.nookTitle).accessibilityHidden(true)
            Text("Unlock to see your things.").font(.nookFootnote).multilineTextAlignment(.center)
        }
        .foregroundStyle(NookColor.textSecondary)
    }
}

private extension WidgetFamily {
    var size: WidgetSize {
        switch self {
        case .systemMedium: .medium
        case .systemLarge, .systemExtraLarge: .large
        default: .small
        }
    }
}

// MARK: Widgets

struct WarrantiesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "warranties", provider: NookProvider()) { entry in
            WarrantiesEntryView(entry: entry)
        }
        .configurationDisplayName("Warranties Ending Soon")
        .description("The warranties that end in the next 30 days.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct WarrantiesEntryView: View {
    let entry: NookEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.isUnavailable {
                LockedWidget()
            } else {
                WarrantiesWidgetView(rows: entry.snapshot.ending.map { ending in
                    WidgetWarranty(id: ending.id, name: ending.name,
                                   daysLeft: max(Warranties.daysLeft(until: ending.end, now: entry.date), 0),
                                   end: ending.end, color: RoomColor(rawValue: ending.colorKey) ?? .stone,
                                   url: DeepLink.item(ending.id).url)
                }, size: family.size)
            }
        }
        .widgetURL(DeepLink.warranties.url)
        .nookWidget()
    }
}

struct ValueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "value", provider: NookProvider()) { entry in
            ValueEntryView(entry: entry)
        }
        .configurationDisplayName("Total Home Value")
        .description("What your things are worth. Hidden when you hide values.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ValueEntryView: View {
    let entry: NookEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.isUnavailable {
                LockedWidget()
            } else {
                ValueWidgetView(total: entry.snapshot.total, currencyCode: HomeCurrency.code,
                                itemCount: entry.snapshot.itemCount,
                                rooms: entry.snapshot.topRooms.map {
                                    WidgetRoomValue(name: $0.name, color: RoomColor(rawValue: $0.colorKey) ?? .stone, total: $0.total)
                                },
                                size: family.size)
            }
        }
        .nookWidget()
    }
}

struct QuickFindWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "quickFind", provider: QuickFindProvider()) { _ in
            QuickFindWidgetView()
                .widgetURL(DeepLink.find(nil).url)
                .nookWidget()
        }
        .configurationDisplayName("Quick Find")
        .description("Ask where something is.")
        .supportedFamilies([.systemSmall])
    }
}

/// Quick find shows no data, so it never reads the store.
struct QuickFindProvider: TimelineProvider {
    func placeholder(in context: Context) -> NookEntry { NookEntry(date: .now, snapshot: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (NookEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NookEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

// MARK: Controls (Control Center, Lock Screen, Action button; D61)

struct ScanRoomControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "pranav.nook.scanRoom") {
            ControlWidgetButton(action: OpenURLIntent(DeepLink.scan.url)) {
                Label("Scan Room", systemImage: "camera.viewfinder")
            }
        }
        .displayName("Scan Room")
        .description("Opens room scan in Nook & Cranny.")
    }
}

struct FindControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "pranav.nook.find") {
            ControlWidgetButton(action: OpenURLIntent(DeepLink.find(nil).url)) {
                Label("Find an Item", systemImage: "magnifyingglass")
            }
        }
        .displayName("Find an Item")
        .description("Opens Find, ready to type.")
    }
}

#if DEBUG
#Preview(as: .systemMedium) { WarrantiesWidget() } timeline: { NookEntry(date: .now, snapshot: .sample) }
#Preview(as: .systemMedium) { ValueWidget() } timeline: { NookEntry(date: .now, snapshot: .sample) }
#Preview(as: .systemSmall) { QuickFindWidget() } timeline: { NookEntry(date: .now, snapshot: .empty) }
#endif
