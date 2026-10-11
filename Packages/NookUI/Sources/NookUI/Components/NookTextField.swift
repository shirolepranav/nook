import SwiftUI

/// A text field (03 §8.6): label above, a sunken well at least 48 pt tall, helper or error
/// text below. Focus draws a 2 pt accent border; an error draws a danger border plus an
/// icon and message, never color alone.
public struct NookTextField: View {
    let label: Text
    @Binding var text: String
    let prompt: Text?
    let helper: Text?
    let error: Text?
    let isSuggested: Bool

    @FocusState private var isFocused: Bool
    @Environment(\.nookAccent) private var accent
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(_ label: Text, text: Binding<String>, prompt: Text? = nil,
                helper: Text? = nil, error: Text? = nil, isSuggested: Bool = false) {
        self.label = label
        self.isSuggested = isSuggested
        self._text = text
        self.prompt = prompt
        self.helper = helper
        self.error = error
    }

    private var borderColor: Color {
        if error != nil { return NookColor.danger }
        return isFocused ? accent.color : .clear
    }

    private var styledLabel: some View {
        label
            .font(.nookFootnote.weight(.semibold))
            .foregroundStyle(NookColor.textSecondary)
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
        VStack(alignment: .leading, spacing: NookSpace.half) {
            // Stacked at accessibility sizes (a size switch, not ViewThatFits, which the
            // audit reads as text that doesn't grow; D51).
            let row = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.half))
                : AnyLayout(HStackLayout(spacing: NookSpace.s1))
            row {
                styledLabel
                if isSuggested { SuggestedLabel() }
            }

            // Placeholder in textSecondary, not textTertiary (D24).
            TextField(text: $text, prompt: prompt?.foregroundStyle(NookColor.textSecondary)) { label }
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .focused($isFocused)
                .accessibilityLabel(label)   // VoiceOver and Voice Control use the visible label
                .padding(.horizontal, NookSpace.s2)
                .padding(.vertical, NookSpace.s1)
                .frame(minHeight: NookLayout.fieldHeight)
                .background(isSuggested ? accent.suggested : NookColor.surfaceSunken, in: shape)
                .overlay { shape.strokeBorder(borderColor, lineWidth: 2) }
                .nookAnimation(.snappy, value: isFocused)

            if let error {
                Label { error } icon: { Image(systemName: "exclamationmark.circle.fill") }
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.danger)
            } else if let helper {
                helper
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// "Suggested" beside a value the model filled in, until the user edits or accepts it
/// (03 §8.5). Never "AI" (03 §12).
public struct SuggestedLabel: View {
    @Environment(\.nookAccent) private var accent

    public init() {}

    public var body: some View {
        Text("Suggested", bundle: .module)
            .font(.nookCaption.weight(.semibold))
            .foregroundStyle(accent.color)
            .padding(.horizontal, NookSpace.s1)
            .background(accent.suggested, in: Capsule())
    }
}
