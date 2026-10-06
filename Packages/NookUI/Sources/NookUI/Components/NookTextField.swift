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

    @FocusState private var isFocused: Bool
    @Environment(\.nookAccent) private var accent

    public init(_ label: Text, text: Binding<String>, prompt: Text? = nil,
                helper: Text? = nil, error: Text? = nil) {
        self.label = label
        self._text = text
        self.prompt = prompt
        self.helper = helper
        self.error = error
    }

    private var borderColor: Color {
        if error != nil { return NookColor.danger }
        return isFocused ? accent.color : .clear
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
        VStack(alignment: .leading, spacing: NookSpace.half) {
            label
                .font(.nookFootnote.weight(.semibold))
                .foregroundStyle(NookColor.textSecondary)

            // Placeholder in textSecondary, not textTertiary (D24).
            TextField(text: $text, prompt: prompt?.foregroundStyle(NookColor.textSecondary)) { label }
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .focused($isFocused)
                .accessibilityLabel(label)   // VoiceOver and Voice Control use the visible label
                .padding(.horizontal, NookSpace.s2)
                .padding(.vertical, NookSpace.s1)
                .frame(minHeight: NookLayout.fieldHeight)
                .background(NookColor.surfaceSunken, in: shape)
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
