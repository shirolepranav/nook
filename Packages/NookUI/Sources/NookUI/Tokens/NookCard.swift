import SwiftUI

public extension View {
    /// The paper surface every card sits on (03 §6, principle 6): opaque `surface`,
    /// a hairline edge, card corners and a warm shadow. Never glass.
    /// It sets the container shape, so `ConcentricRectangle()` inside follows the card.
    func nookCard(radius: CGFloat = NookRadius.card, elevation: NookElevation = .low) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(NookColor.surface, in: shape)
            .overlay { shape.strokeBorder(NookColor.hairline, lineWidth: 1) }
            .containerShape(shape)
            .warmShadow(elevation)
    }
}
