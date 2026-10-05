import SwiftUI

/// Buttons (03 §8.2). One primary per screen. Floating controls use the system
/// `.glass`/`.glassProminent` styles instead (glass for controls only).
public struct NookButtonStyle: ButtonStyle {
    public enum Kind: Sendable {
        /// Capsule, accent fill, `onAccent` label, 50 pt tall: Save, Save All, Unlock Pro.
        case primary
        /// Capsule, accent at 12% (18% dark), `textPrimary` label: Edit, Add Spot, Try Again.
        case secondary
        /// Accent text only: Cancel-like actions and links.
        case tertiary
        /// Danger text only: Delete.
        case destructive
    }

    let kind: Kind
    let isLoading: Bool

    public init(_ kind: Kind, isLoading: Bool = false) {
        self.kind = kind
        self.isLoading = isLoading
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, kind: kind, isLoading: isLoading)
    }
}

public extension ButtonStyle where Self == NookButtonStyle {
    static var nookPrimary: NookButtonStyle { NookButtonStyle(.primary) }
    static var nookSecondary: NookButtonStyle { NookButtonStyle(.secondary) }
    static var nookTertiary: NookButtonStyle { NookButtonStyle(.tertiary) }
    static var nookDestructive: NookButtonStyle { NookButtonStyle(.destructive) }
}

private struct StyledButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: NookButtonStyle.Kind
    let isLoading: Bool

    @Environment(\.nookAccent) private var accent
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // A capsule at the normal 50 pt height; when large text makes the button taller it
    // stays a rounded rectangle instead of ballooning into an oval.
    static let shape = RoundedRectangle(cornerRadius: NookLayout.buttonHeight / 2, style: .continuous)

    private var isFilled: Bool { kind == .primary || kind == .secondary }

    private var foreground: Color {
        switch kind {
        case .primary: accent.onAccent
        case .secondary: NookColor.textPrimary
        case .tertiary: accent.color
        case .destructive: NookColor.danger
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: accent.color
        case .secondary: accent.suggested
        case .tertiary, .destructive: .clear
        }
    }

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .labelStyle(ButtonLabelStyle())
            .font(.nookHeadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            // Loading keeps the label's width so the button doesn't jump (03 §8.2).
            .opacity(isLoading ? 0 : 1)
            .overlay { if isLoading { ProgressView().tint(foreground) } }
            .padding(.horizontal, isFilled ? NookSpace.s3 : NookSpace.s1)
            .padding(.vertical, NookSpace.s1)
            .frame(minHeight: isFilled ? NookLayout.buttonHeight : NookLayout.minTapTarget)
            .background(fill, in: Self.shape)
            .contentShape(Self.shape)
            // The button always takes the height its label needs, so a crowded parent can't
            // squeeze it below a wrapped label at large text sizes (03 §3: never truncate).
            .fixedSize(horizontal: false, vertical: true)
            // Pressed: shrink to 97%; under Reduce Motion, dim instead (03 §9).
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .opacity(pressed && reduceMotion ? 0.7 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .nookAnimation(.snappy, value: pressed)
            .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }
}

/// Icon beside the title; at accessibility text sizes the icon sits above it so the title
/// has the full width to wrap (03 §3: wrap, never truncate).
private struct ButtonLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var typeSize

    func makeBody(configuration: Configuration) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: NookSpace.half))
            : AnyLayout(HStackLayout(spacing: NookSpace.s1))
        layout {
            configuration.icon.accessibilityHidden(true)
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}
