import SwiftUI

/// An item as a photo card (03 §8.3): 4:5 photo, name on up to 2 lines, the location below,
/// corner badges. VoiceOver reads it as one element: name, location, value (03 §11).
public struct PhotoCard: View {
    let name: String
    let location: String
    let photo: Image?
    let badges: [CardBadge.Kind]
    let value: (amount: Decimal, currencyCode: String)?
    let isSelected: Bool?

    @AppStorage(MoneyText.hideValuesKey) private var hideValues = false
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(name: String, location: String, photo: Image? = nil, badges: [CardBadge.Kind] = [],
                value: (amount: Decimal, currencyCode: String)? = nil, isSelected: Bool? = nil) {
        self.isSelected = isSelected
        self.name = name
        self.location = location
        self.photo = photo
        self.badges = badges
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            NookPhoto(photo)
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    Group {
                        if let isSelected {
                            SelectionMark(isSelected: isSelected)   // I-08 replaces the badges
                        } else {
                            HStack(spacing: NookSpace.half) {
                                ForEach(badges, id: \.self) { CardBadge($0) }
                            }
                        }
                    }
                    .padding(NookSpace.s1)
                }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: name)
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Text(verbatim: location)
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)   // never cut off a place (03 §8.4)
            }
            .padding([.horizontal, .bottom], NookSpace.half)
        }
        .padding(NookSpace.s1)
        .nookCard()
        .hoverEffect(.lift)   // D29: pointer
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        var parts = [Text(verbatim: name), Text(verbatim: location)]
        if let value {
            parts.append(hideValues
                ? Text("Value hidden", bundle: .module)
                : Text(value.amount, format: .currency(code: value.currencyCode)))
        }
        for badge in badges { parts.append(badge.label) }
        if let isSelected { parts.append(SelectionMark.label(isSelected)) }
        return parts.dropFirst().reduce(parts[0]) { Text("\($0), \($1)") }
    }
}

/// A photo inside a card: fills its frame, clipped concentric to the card (03 §5).
/// With no photo yet, a sunken placeholder with a quiet symbol.
struct NookPhoto: View {
    let image: Image?

    init(_ image: Image?) { self.image = image }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        NookColor.surfaceSunken
                        Image(systemName: "photo")
                            .font(.nookTitle)
                            .foregroundStyle(NookColor.textTertiary)
                    }
                }
            }
            .clipShape(ConcentricRectangle())
            // Photos are never inverted by Smart Invert (03 §11).
            .accessibilityIgnoresInvertColors()
    }
}

/// A room as a card (03 §8.3): the room's soft color, its symbol in the room's ink, the
/// item count, and the name. Shelf-like: wider than tall.
public struct RoomCard: View {
    let name: String
    let symbol: String
    let color: RoomColor
    let itemCount: Int

    public init(name: String, symbol: String, color: RoomColor, itemCount: Int) {
        self.name = name
        self.symbol = symbol
        self.color = color
        self.itemCount = itemCount
    }

    private var countText: Text {
        itemCount == 0 ? Text("Empty", bundle: .module) : Text("\(itemCount) items", bundle: .module)
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.card, style: .continuous)
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            HStack(alignment: .firstTextBaseline, spacing: NookSpace.s1) {
                Image(systemName: symbol).font(.nookSection)
                Spacer(minLength: 0)
                countText.font(.nookMeta)
            }
            .foregroundStyle(color.ink)
            Spacer(minLength: 0)
            Text(verbatim: name)
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, minHeight: NookLayout.roomCardMinHeight, alignment: .leading)
        .background(color.fill, in: shape)
        .containerShape(shape)
        .hoverEffect(.lift)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(verbatim: name)), \(countText)"))
    }
}

/// The dashed "add" card at the end of a grid (03 §8.3): "Add room", "Add spot".
public struct AddCard: View {
    let title: Text

    public init(_ title: Text) { self.title = title }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.card, style: .continuous)
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Image(systemName: "plus")
                .font(.nookSection)
                .foregroundStyle(NookColor.textSecondary)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            title
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, minHeight: NookLayout.roomCardMinHeight, alignment: .leading)
        .overlay { shape.strokeBorder(NookColor.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])) }
        .contentShape(shape)
        .hoverEffect(.highlight)
    }
}

/// Makes a card tappable: lifts and shrinks to 98% while pressed (03 §8.3); dims instead
/// under Reduce Motion. Use on the Button or NavigationLink wrapping a card.
public struct NookCardButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CardPress(configuration: configuration)
    }
}

public extension ButtonStyle where Self == NookCardButtonStyle {
    static var nookCard: NookCardButtonStyle { NookCardButtonStyle() }
}

private struct CardPress: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .opacity(pressed && reduceMotion ? 0.7 : 1)
            .warmShadow(pressed ? .lifted : .flat)   // the card already has its low shadow
            .nookAnimation(.snappy, value: pressed)
    }
}
