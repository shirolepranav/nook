import SwiftUI

/// What a toast says (03 §8.9): an icon, one short sentence, and Undo when the action can
/// be reversed. "Moved to Kitchen → Pantry." "Deleted. You can restore it for 30 days."
public struct ToastMessage: Identifiable {
    public let id = UUID()
    let symbol: String
    let text: LocalizedStringResource
    let undo: (() -> Void)?

    public init(symbol: String = "checkmark.circle.fill", _ text: LocalizedStringResource,
                undo: (() -> Void)? = nil) {
        self.symbol = symbol
        self.text = text
        self.undo = undo
    }
}

public extension View {
    /// Shows `message` as a toast at the bottom for 5 seconds (D14) and announces it to VoiceOver.
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastPresenter(message: message))
    }
}

private struct ToastPresenter: ViewModifier {
    @Binding var message: ToastMessage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let current = message {
                ToastView(message: current) { message = nil }
                    .padding(NookSpace.s2)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .task(id: current.id) {
                        AccessibilityNotification.Announcement(String(localized: current.text)).post()
                        try? await Task.sleep(for: .seconds(5))
                        if message?.id == current.id { message = nil }
                    }
            }
        }
        .nookAnimation(.settle, value: message?.id)
    }
}

struct ToastView: View {
    let message: ToastMessage
    let dismiss: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.toast, style: .continuous)
        HStack(spacing: NookSpace.s1 + NookSpace.half) {
            Image(systemName: message.symbol)
                .foregroundStyle(NookColor.success)
                .accessibilityHidden(true)
            Text(message.text)
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let undo = message.undo {
                Button {
                    undo()
                    dismiss()
                } label: {
                    Text("Undo", bundle: .module)
                }
                .buttonStyle(.nookTertiary)
            }
        }
        .padding(.leading, NookSpace.s2)
        .padding(.trailing, NookSpace.s1)
        .padding(.vertical, NookSpace.s1 + NookSpace.half)
        .frame(maxWidth: NookLayout.readableWidth)
        .background(NookColor.surfaceRaised, in: shape)
        .overlay { shape.strokeBorder(NookColor.hairline, lineWidth: 1) }
        .warmShadow(.floating)
        .accessibilityElement(children: .contain)
    }
}
