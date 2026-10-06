import SwiftUI

/// A status pill (03 §8.7). Always icon plus text plus color, never color alone (03 §2.4).
public struct StatusPill: View {
    public enum Status: Sendable {
        case active, endingSoon, expired, lent
        /// I-01's Private badge: quiet, not a warning.
        case privateItem

        var color: Color {
            switch self {
            case .active: NookColor.success
            case .endingSoon: NookColor.warning
            case .expired: NookColor.danger
            case .lent: NookColor.info
            case .privateItem: NookColor.textSecondary
            }
        }

        var symbol: String {
            switch self {
            case .active: "checkmark.shield"
            case .endingSoon: "clock"
            case .expired: "exclamationmark.triangle"
            case .lent: "person.crop.circle.badge.clock"
            case .privateItem: "lock.fill"
            }
        }
    }

    let status: Status
    let text: Text

    /// `text` says what the status means: "Ends in 12 days", "Expired Mar 3", "Lent to Jordan".
    public init(_ status: Status, _ text: Text) {
        self.status = status
        self.text = text
    }

    public var body: some View {
        Label { text } icon: { Image(systemName: status.symbol) }
            .labelStyle(PillLabelStyle())
            .font(.nookCaption)
            .foregroundStyle(status.color)
            .padding(.horizontal, NookSpace.s1)
            .padding(.vertical, NookSpace.half)
            .background(status.color.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

private struct PillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: NookSpace.half) {
            configuration.icon.accessibilityHidden(true)
            configuration.title
        }
    }
}

/// A small glyph in a card's corner (03 §8.7): Private, Lent, warranty ending.
public struct CardBadge: View {
    public enum Kind: Sendable {
        case privateItem, lent, endingSoon

        var symbol: String {
            switch self {
            case .privateItem: "lock.fill"
            case .lent: "person.fill"
            case .endingSoon: "clock.fill"
            }
        }

        var label: Text {
            switch self {
            case .privateItem: Text("Private", bundle: .module)
            case .lent: Text("Lent", bundle: .module)
            case .endingSoon: Text("Warranty ending soon", bundle: .module)
            }
        }
    }

    let kind: Kind

    public init(_ kind: Kind) { self.kind = kind }

    public var body: some View {
        Image(systemName: kind.symbol)
            .font(.nookCaption)
            // A badge sits on a photo card whose text already scales; a growing glyph would
            // cover the photo and overflow its 24 pt circle. VoiceOver reads the label.
            .dynamicTypeSize(...DynamicTypeSize.large)
            .foregroundStyle(NookColor.textPrimary)
            .frame(width: NookLayout.badgeSize, height: NookLayout.badgeSize)
            .background(NookColor.surfaceRaised, in: Circle())
            .overlay { Circle().strokeBorder(NookColor.hairline, lineWidth: 1) }
            .accessibilityLabel(kind.label)
    }
}
