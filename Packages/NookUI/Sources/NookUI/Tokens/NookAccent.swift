import SwiftUI

public extension EnvironmentValues {
    /// The user's accent (S-06). Components need it for `onAccent` and the 12% fills,
    /// which `.tint` alone can't give them.
    @Entry var nookAccent: AccentChoice = .terracotta
}

public extension View {
    /// Applies the user's accent app-wide: the tint for system controls, and the
    /// environment value NookUI components read.
    func nookAccent(_ accent: AccentChoice) -> some View {
        tint(accent.color).environment(\.nookAccent, accent)
    }
}
