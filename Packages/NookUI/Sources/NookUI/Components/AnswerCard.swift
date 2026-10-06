import SwiftUI

/// The answer card on Find (03 §8, F-03): raised paper with the hero radius and the floating
/// shadow, holding one answer. Content, so never glass (03 §1.6). It sets the container shape,
/// so photos inside with `ConcentricRectangle` follow its corners.
public struct AnswerCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.hero, style: .continuous)
        VStack(alignment: .leading, spacing: NookSpace.s2) { content }
            .padding(NookSpace.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NookColor.surfaceRaised, in: shape)
            .overlay { shape.strokeBorder(NookColor.hairline, lineWidth: 1) }
            .containerShape(shape)
            .warmShadow(.floating)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Answer", bundle: .module))
    }
}

/// A photo on the answer card (item, spot): 4:3, corners following the card.
public struct AnswerPhoto: View {
    let image: Image?

    public init(_ image: Image?) { self.image = image }

    public var body: some View {
        NookPhoto(image).aspectRatio(4 / 3, contentMode: .fit)
    }
}

/// "Office → Desk → Second drawer" with the room in its ink (01 §1.2, the Find boards).
public enum Breadcrumb {
    /// `names` starts with the room. `ending` follows the last name ("." on the answer card).
    public static func text(_ names: [String], color: RoomColor, ending: String = "") -> Text {
        guard let room = names.first else { return Text(verbatim: ending) }
        var roomPart = AttributedString(room)
        roomPart.foregroundColor = color.ink
        roomPart.inlinePresentationIntent = .stronglyEmphasized
        let rest = names.dropFirst().map { " → " + $0 }.joined() + ending
        return Text(roomPart + AttributedString(rest))
    }
}
