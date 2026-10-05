import SwiftUI

/// A filter chip (03 §8.7, F-05). Selected: accent at 12% with a checkmark.
public struct FilterChip: View {
    let title: Text
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.nookAccent) private var accent

    public init(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(title)
        self.isSelected = isSelected
        self.action = action
    }

    public init(verbatim title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: NookSpace.s1) {
                title
                if isSelected {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ChipStyle(fill: isSelected ? accent.suggested : NookColor.surface,
                               bordered: !isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .nookHaptic(.selected, trigger: isSelected)
    }
}

/// A room chip (03 §8.7, O-02, F-05): the room's symbol in its ink; selected fills with
/// the room color and adds a checkmark.
public struct RoomChip: View {
    let name: String
    let symbol: String
    let color: RoomColor
    let isSelected: Bool
    let action: () -> Void

    public init(name: String, symbol: String, color: RoomColor, isSelected: Bool, action: @escaping () -> Void) {
        self.name = name
        self.symbol = symbol
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: NookSpace.s1) {
                Image(systemName: symbol).foregroundStyle(color.ink).accessibilityHidden(true)
                Text(verbatim: name)
                if isSelected {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ChipStyle(fill: isSelected ? color.fill : NookColor.surface, bordered: !isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .nookHaptic(.selected, trigger: isSelected)
    }
}

/// Shared chip shape: 44 pt capsule (the mockups draw chips at the full tap height).
struct ChipStyle: ButtonStyle {
    let fill: Color
    let bordered: Bool

    // A capsule at 44 pt; a rounded rectangle when large text makes the chip taller.
    private static let shape = RoundedRectangle(cornerRadius: NookLayout.minTapTarget / 2, style: .continuous)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nookBody.weight(.semibold))
            .foregroundStyle(NookColor.textPrimary)
            .padding(.horizontal, NookSpace.s2)
            .padding(.vertical, NookSpace.s1)
            .frame(minHeight: NookLayout.minTapTarget)
            .background(fill, in: Self.shape)
            .overlay { if bordered { Self.shape.strokeBorder(NookColor.hairline, lineWidth: 1) } }
            .contentShape(Self.shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .nookAnimation(.snappy, value: configuration.isPressed)
    }
}
