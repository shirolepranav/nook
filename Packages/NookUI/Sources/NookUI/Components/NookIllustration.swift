import SwiftUI

/// The empty-state illustrations (03 §7, D25). Each is a base layer with light and dark
/// versions plus a one-color layer tinted with the user's accent. Decorative, so VoiceOver
/// skips them.
public enum NookIllustration: String, CaseIterable, Sendable {
    case shelfTidy = "shelf-tidy"           // Welcome
    case shelfWaiting = "shelf-waiting"     // empty Home
    case kitchenEmpty = "kitchen-empty"     // empty room
    case drawerEmpty = "drawer-empty"       // no search results
    case shelfFull = "shelf-full"           // paywall
    case receiptRibbon = "receipt-ribbon"   // no warranties
    case boxHands = "box-hands"             // nothing lent
    case binEmpty = "bin-empty"             // Recently Deleted
}

/// Draws an illustration: base layer, then the accent layer in the current tint.
public struct IllustrationView: View {
    let illustration: NookIllustration

    public init(_ illustration: NookIllustration) {
        self.illustration = illustration
    }

    public var body: some View {
        ZStack {
            Image(illustration.rawValue, bundle: .module)
                .resizable()
                .scaledToFit()
            Image("\(illustration.rawValue)-accent", bundle: .module)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tint)
        }
        .accessibilityHidden(true)
    }
}
