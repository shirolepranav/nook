import SwiftUI

/// The empty state every data screen has (01 §1.3, 03 §8.9): an illustration, one
/// sentence and one action, on a paper card.
public struct EmptyStateView<Action: View>: View {
    let illustration: NookIllustration
    let title: Text
    let message: Text
    let action: Action

    public init(_ illustration: NookIllustration, title: Text, message: Text,
                @ViewBuilder action: () -> Action) {
        self.illustration = illustration
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: NookSpace.s2) {
            IllustrationView(illustration)
                .frame(maxWidth: .infinity)
                .frame(height: NookLayout.illustrationHeight)
            title
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate (03 §3)
                .accessibilityAddTraits(.isHeader)
            message
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            action
        }
        .multilineTextAlignment(.center)
        .padding(NookSpace.s3)
        .frame(maxWidth: .infinity)
        .nookCard()
    }
}

public extension EmptyStateView where Action == EmptyView {
    /// An empty state whose action arrives in a later phase, or that needs none.
    init(_ illustration: NookIllustration, title: Text, message: Text) {
        self.init(illustration, title: title, message: message) { EmptyView() }
    }
}

/// The rare error state (01 §1.3, 03 §8.9): a calm symbol, the plain reason, reassurance
/// and Retry. Never mentions AI, and never shows a system error's text.
public struct ErrorStateView: View {
    let symbol: String
    let title: Text
    let message: Text
    let retry: () -> Void

    /// `message` carries the reassurance: "Your items are safe on this iPhone. Try again in a moment."
    public init(symbol: String = "exclamationmark.triangle", title: Text, message: Text,
                retry: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: NookSpace.s2) {
            Image(systemName: symbol)
                .font(.nookTitle)
                .foregroundStyle(NookColor.textSecondary)
                .frame(width: NookLayout.stateIconSize, height: NookLayout.stateIconSize)
                .background(NookColor.surfaceSunken, in: Circle())
                .accessibilityHidden(true)
            title
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate (03 §3)
                .accessibilityAddTraits(.isHeader)
            message
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label { Text("Try Again", bundle: .module) } icon: { Image(systemName: "arrow.clockwise") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(NookSpace.s3)
        .frame(maxWidth: .infinity)
        .nookCard()
    }
}

/// A loading placeholder shaped like a photo card (03 §8.9): sunken blocks with a slow
/// shimmer, static under Reduce Motion. Spinners only for waits under a second (01 §1.3).
public struct SkeletonCard: View {
    @State private var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            ConcentricRectangle()
                .fill(NookColor.surfaceSunken)
                .aspectRatio(4 / 5, contentMode: .fit)
            bar(height: NookSpace.s2, fraction: 0.7)                    // name line
            bar(height: NookSpace.s1 + NookSpace.half, fraction: 0.5)   // breadcrumb line
        }
        .padding(NookSpace.s1)
        .opacity(dimmed ? 0.6 : 1)
        .nookCard()
        .onAppear {
            guard !reduceMotion else { return }
            withNookAnimation(.shimmer, reduceMotion: reduceMotion) { dimmed = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Loading", bundle: .module))
    }

    private func bar(height: CGFloat, fraction: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(NookColor.surfaceSunken).frame(width: proxy.size.width * fraction)
                }
            }
    }
}
