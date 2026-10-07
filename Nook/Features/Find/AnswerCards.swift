import SwiftUI
import NookKit
import NookUI

/// What the answer card can do: move (or "Found it here", D44) through the screen's
/// `ItemActions`, and open a place or an item.
struct AnswerActions {
    let move: (Item, LocationEvent.Source) -> Void
    let open: (any Hashable) -> Void
}

/// F-03: one answer, built from records only (PRD §6). The screen resolves the models; an
/// answer whose item or place is gone shows nothing.
struct AnswerView: View {
    let answer: FindAnswer
    let item: Item?
    let place: Location?
    let actions: AnswerActions

    var body: some View {
        switch answer {
        case .location:
            if let item, let location = Location(of: item) { LocationAnswer(item: item, location: location, actions: actions) }
        case .quantity(_, let count):
            if let item, let location = Location(of: item) {
                LocationAnswer(item: item, location: location, actions: actions,
                               headline: Text("Yes, you have \(count)."))
            }
        case .lent(_, let person, let since, let due):
            if let item { LentAnswer(item: item, person: person, since: since, due: due) }
        case .packed(_, _, let date):
            if let item, let location = Location(of: item), let box = location.spot {
                PackedAnswer(item: item, location: location, box: box, date: date, actions: actions)
            }
        case .contents(_, let total, let groups):
            if let place { ContentsAnswer(place: place, total: total, groups: groups, actions: actions) }
        }
    }
}

// MARK: Variants

/// "Office → Desk → Second drawer." with the last confirmed date, the item and spot photos,
/// and Move / Found It Here Instead (01 F-03, §1.2).
private struct LocationAnswer: View {
    let item: Item
    let location: Location
    let actions: AnswerActions
    var headline: Text?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        AnswerCard {
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text(verbatim: item.name)
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.textSecondary)
                if let headline {
                    headline.font(.nookSection).foregroundStyle(NookColor.textPrimary)
                }
                Breadcrumb.text(location.names, color: location.roomColor, ending: ".")
                    .font(headline == nil ? .nookSection : .nookBody)
                    .foregroundStyle(NookColor.textPrimary)
                Text("Last confirmed \(item.lastConfirmedAt, format: .dateTime.month(.abbreviated).day()).")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            AnswerPhotos(item: item, spot: location.spot, actions: actions)
            let buttons = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: NookSpace.s1)) : AnyLayout(HStackLayout(spacing: NookSpace.s1))
            buttons {
                Button("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right") { actions.move(item, .manual) }
                    .buttonStyle(.nookPrimary)
                Button("Found It Here Instead") { actions.move(item, .found) }
                    .buttonStyle(.nookSecondary)
            }
        }
    }
}

/// "Jordan has your cordless drill. Since Sep 12 · due back Oct 1." Read-only until lending
/// arrives in P7, which adds Mark Returned (D46).
private struct LentAnswer: View {
    let item: Item
    let person: String
    let since: Date
    let due: Date?

    var body: some View {
        AnswerCard {
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text("\(Text(verbatim: person).foregroundStyle(NookColor.info)) has your \(item.name).")
                    .font(.nookSection)
                    .foregroundStyle(NookColor.textPrimary)
                Group {
                    if let due {
                        Text("Since \(since, format: .dateTime.month(.abbreviated).day()) · due back \(due, format: .dateTime.month(.abbreviated).day()).")
                    } else {
                        Text("Since \(since, format: .dateTime.month(.abbreviated).day()).")
                    }
                }
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            StatusPill(.lent, Text("Lent out"))
        }
    }
}

/// "Box 14, packed Jun 2." with where the box is, and Open Box 14.
private struct PackedAnswer: View {
    let item: Item
    let location: Location
    let box: Spot
    let date: Date
    let actions: AnswerActions

    var body: some View {
        AnswerCard {
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text("\(box.name), packed \(date, format: .dateTime.month(.abbreviated).day()).")
                    .font(.nookSection)
                    .foregroundStyle(NookColor.textPrimary)
                Text("\(Breadcrumb.text(location.names, color: location.roomColor)) · \(item.name)")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            AnswerPhotos(item: item, spot: box, actions: actions)
            Button("Open \(box.name)") { actions.open(box) }
                .buttonStyle(.nookSecondary)
        }
    }
}

/// "22 things in the Garage." Then each spot with up to 4 names and "+N more".
private struct ContentsAnswer: View {
    let place: Location
    let total: Int
    let groups: [ContentsGroup]
    let actions: AnswerActions

    private static let namesShown = 4

    var body: some View {
        let name = place.spot?.name ?? place.room.name
        AnswerCard {
            Text("\(total) things in \(Breadcrumb.text([name], color: place.roomColor)).")
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(groups, id: \.place) { group in
                VStack(alignment: .leading, spacing: NookSpace.half) {
                    Text("\(group.name ?? String(localized: "Not in a spot")) · \(group.count)")
                        .font(.nookFootnote.weight(.semibold))
                        .foregroundStyle(NookColor.textSecondary)
                    Text(verbatim: summary(group))
                        .font(.nookBody)
                        .foregroundStyle(NookColor.textPrimary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
            Button("Open \(name)") { actions.open(place.spot.map { $0 as any Hashable } ?? place.room) }
                .buttonStyle(.nookSecondary)
        }
    }

    /// "Cordless drill, Level, Stud finder, +5 more". Private things count but aren't named.
    private func summary(_ group: ContentsGroup) -> String {
        let shown = group.itemNames.prefix(Self.namesShown)
        let more = group.count - shown.count
        let names = shown.joined(separator: ", ")
        guard more > 0 else { return names }
        let rest = String(localized: "+\(more) more")
        return names.isEmpty ? rest : "\(names), \(rest)"
    }
}

/// The item's photo and its spot's photo side by side (03 §8). Tapping opens them.
private struct AnswerPhotos: View {
    let item: Item
    let spot: Spot?
    let actions: AnswerActions

    var body: some View {
        let itemPhoto = item.cover?.fileName
        let spotPhoto = spot?.photo?.fileName
        if itemPhoto != nil || spotPhoto != nil {
            HStack(spacing: NookSpace.s1) {
                if let itemPhoto {
                    Button { actions.open(item) } label: {
                        StoredImage(fileName: itemPhoto) { AnswerPhoto($0) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Open \(item.name)"))
                }
                if let spot, let spotPhoto {
                    Button { actions.open(spot) } label: {
                        StoredImage(fileName: spotPhoto) { AnswerPhoto($0) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Open \(spot.name)"))
                }
                if itemPhoto == nil || spotPhoto == nil { Color.clear }   // one photo keeps half the width
            }
            .dynamicTypeSize(...DynamicTypeSize.large)   // the placeholder glyph is fixed-size
        }
    }
}

extension Location {
    var roomColor: RoomColor { RoomColor(rawValue: room.colorKey) ?? .stone }
}
