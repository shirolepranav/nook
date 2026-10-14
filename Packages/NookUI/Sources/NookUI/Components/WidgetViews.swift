import SwiftUI
import WidgetKit

// The Home Screen widgets' content (F10, W01Widgets board). In NookUI so they're snapshot
// tested with the other components; the widget extension feeds them from the App Group
// store. Accent parts are `widgetAccentable`, so the tinted and clear styles recolor them.

/// small, medium, large: the widget families Nook supports (F10).
public enum WidgetSize: Sendable {
    case small, medium, large

    /// The iPhone SE's widget sizes, for previews and snapshots.
    public var previewSize: CGSize {
        switch self {
        case .small: CGSize(width: 148, height: 148)
        case .medium: CGSize(width: 321, height: 148)
        case .large: CGSize(width: 321, height: 324)
        }
    }
}

/// One warranty row: never a Private item (PRD §9).
public struct WidgetWarranty: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let daysLeft: Int
    public let end: Date
    public let color: RoomColor
    public let url: URL?

    public init(id: UUID, name: String, daysLeft: Int, end: Date, color: RoomColor, url: URL? = nil) {
        (self.id, self.name, self.daysLeft, self.end, self.color, self.url) = (id, name, daysLeft, end, color, url)
    }
}

private struct WidgetHeader: View {
    let title: Text
    let symbol: String
    @Environment(\.nookAccent) private var accent

    var body: some View {
        Label { title } icon: { Image(systemName: symbol) }
            .font(.nookFootnote.weight(.bold))
            .foregroundStyle(accent.color)
            .widgetAccentable()
            .lineLimit(1)
    }
}

/// "Warranties ending soon" (01 §12).
public struct WarrantiesWidgetView: View {
    let rows: [WidgetWarranty]
    let size: WidgetSize

    public init(rows: [WidgetWarranty], size: WidgetSize) {
        self.rows = rows
        self.size = size
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            WidgetHeader(title: Text("Warranties", bundle: .module), symbol: "clock")
            if rows.isEmpty {
                VStack(spacing: NookSpace.s1) {
                    Image(systemName: "checkmark.shield").font(.nookTitle).accessibilityHidden(true)
                    Text("No warranties ending soon.", bundle: .module).font(.nookFootnote).multilineTextAlignment(.center)
                }
                .foregroundStyle(NookColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if size == .small, let first = rows.first {
                Spacer(minLength: 0)
                days(first.daysLeft)
                    .font(.nookTitle)
                    .foregroundStyle(NookColor.textPrimary)
                    .minimumScaleFactor(0.7)
                Text(verbatim: first.name)
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.textPrimary)
                    .lineLimit(1)
                if rows.count > 1 {
                    Text("+\(rows.count - 1) more", bundle: .module)
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                        .lineLimit(1)
                }
            } else {
                ForEach(rows.prefix(size == .medium ? 2 : 5)) { row in
                    Link(destination: row.url ?? URL(string: "nook://warranties")!) { WarrantyRow(row: row, when: when(row)) }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func days(_ left: Int) -> Text {
        left == 0 ? Text("Today", bundle: .module) : Text("\(left) days", bundle: .module)
    }

    private func when(_ row: WidgetWarranty) -> Text {
        row.daysLeft == 0 ? Text("Ends today", bundle: .module) : Text("Ends in \(row.daysLeft) days", bundle: .module)
    }
}

private struct WarrantyRow: View {
    let row: WidgetWarranty
    let when: Text

    var body: some View {
        HStack(spacing: NookSpace.s1) {
            RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
                .fill(row.color.fill)
                .frame(width: NookLayout.minTapTarget - NookSpace.half, height: NookLayout.minTapTarget - NookSpace.half)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: row.name).font(.nookMeta.weight(.semibold)).foregroundStyle(NookColor.textPrimary).lineLimit(1)
                when.font(.nookFootnote).foregroundStyle(NookColor.warning).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One room's share of the Total value widget.
public struct WidgetRoomValue: Sendable {
    public let name: String
    public let color: RoomColor
    public let total: Decimal

    public init(name: String, color: RoomColor, total: Decimal) {
        (self.name, self.color, self.total) = (name, color, total)
    }
}

/// "Total home value" (01 §12): honors Hide values through `MoneyText` (D28).
public struct ValueWidgetView: View {
    let total: Decimal
    let currencyCode: String
    let itemCount: Int
    let rooms: [WidgetRoomValue]
    let size: WidgetSize

    public init(total: Decimal, currencyCode: String, itemCount: Int, rooms: [WidgetRoomValue], size: WidgetSize) {
        (self.total, self.currencyCode, self.itemCount, self.rooms, self.size) = (total, currencyCode, itemCount, rooms, size)
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: NookSpace.s2) {
            VStack(alignment: .leading, spacing: NookSpace.half) {
                WidgetHeader(title: Text("Home value", bundle: .module), symbol: "house")
                Spacer(minLength: 0)
                if total == 0 && itemCount > 0 {
                    Text("Add prices to see your total.", bundle: .module)
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                } else {
                    MoneyText(total, currencyCode: currencyCode, font: .nookTitle, wholeUnits: true)
                        .foregroundStyle(NookColor.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Text("\(itemCount) items", bundle: .module)
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            if size != .small, !rooms.isEmpty {
                VStack(alignment: .leading, spacing: NookSpace.s1) {
                    ForEach(rooms, id: \.name) { room in
                        HStack(spacing: NookSpace.s1) {
                            Circle().fill(room.color.ink).frame(width: NookSpace.s1, height: NookSpace.s1)
                                .accessibilityHidden(true)
                            Text(verbatim: room.name).lineLimit(1)
                            Spacer(minLength: NookSpace.half)
                            MoneyText(room.total, currencyCode: currencyCode, font: .nookFootnote, wholeUnits: true)
                                .lineLimit(1)
                                .fixedSize()   // the name gives way, never the value
                        }
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
        }
    }
}

/// "Quick find" (01 §12): opens Find with the field focused.
public struct QuickFindWidgetView: View {
    @Environment(\.nookAccent) private var accent

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.half) {
            Image(systemName: "magnifyingglass")
                .font(.nookTitle)
                .foregroundStyle(accent.color)
                .frame(width: NookLayout.cameraControlSize, height: NookLayout.cameraControlSize)
                .background(accent.suggested, in: Circle())   // the accent at 12% (03 §2.4)
                .widgetAccentable()
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text("Find anything", bundle: .module).font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
            Text("Where’s my…?", bundle: .module).font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
