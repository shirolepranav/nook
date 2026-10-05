import SwiftUI

/// Elevation levels (03 §6.2). Light mode uses warm brown shadows; dark mode uses none,
/// because lighter surfaces and hairlines carry elevation there.
public enum NookElevation: Sendable {
    case flat       // no shadow
    case low        // cards
    case lifted     // pressed or dragging
    case floating   // toasts, answer card
}

public extension View {
    func warmShadow(_ level: NookElevation = .low) -> some View {
        modifier(WarmShadow(level: level))
    }
}

struct WarmShadow: ViewModifier {
    let level: NookElevation
    @Environment(\.colorScheme) private var scheme

    // Warm brown instead of black: softer on the linen canvas (03 §6.2).
    private static let brown = Color(red: 0.35, green: 0.23, blue: 0.13)

    func body(content: Content) -> some View {
        if scheme == .dark {
            content
        } else {
            switch level {
            case .flat:
                content
            case .low:
                content
                    .shadow(color: Self.brown.opacity(0.06), radius: 8, y: 2)
                    .shadow(color: Self.brown.opacity(0.04), radius: 2, y: 1)
            case .lifted:
                content.shadow(color: Self.brown.opacity(0.10), radius: 20, y: 8)
            case .floating:
                content.shadow(color: Self.brown.opacity(0.14), radius: 32, y: 16)
            }
        }
    }
}
