import SwiftUI

/// Motion tokens (03 §9). Nothing runs longer than 0.6 s, and only `shimmer` loops.
/// Use `.nookAnimation(_:value:)` or `withNookAnimation(_:_:)` so Reduce Motion is handled here.
public enum NookMotion: Sendable {
    /// Button press, chip selection, toggles.
    case snappy
    /// Card settling after save, outlines appearing, move confirmed.
    case settle
    /// Filters changing, state swaps (empty ↔ loaded).
    case fade
    /// Loading skeletons only.
    case shimmer

    /// The animation to run. Under Reduce Motion it's the calmer version from 03 §9,
    /// and `nil` for `shimmer` (skeletons stay static). Components that scale or slide
    /// must also swap that change for an opacity change when `reduceMotion` is on.
    public func animation(reduceMotion: Bool) -> Animation? {
        switch (self, reduceMotion) {
        case (.snappy, _): .easeOut(duration: 0.2)
        case (.settle, false): .spring(duration: 0.35, bounce: 0.2)
        case (.settle, true): .easeInOut(duration: 0.25)
        case (.fade, _): .easeInOut(duration: 0.3)
        case (.shimmer, false): .linear(duration: 1.6).repeatForever(autoreverses: false)
        case (.shimmer, true): nil
        }
    }

    /// Delay between items appearing one after another (detection outlines, streamed cards).
    /// No stagger under Reduce Motion; haptics stay.
    public static func stagger(reduceMotion: Bool) -> Duration {
        reduceMotion ? .zero : .milliseconds(180)
    }
}

public extension View {
    /// Animates changes to `value` with a motion token, honoring Reduce Motion.
    func nookAnimation(_ motion: NookMotion, value: some Equatable) -> some View {
        modifier(NookAnimationModifier(motion: motion, value: value))
    }
}

private struct NookAnimationModifier<Value: Equatable>: ViewModifier {
    let motion: NookMotion
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
    }
}

/// `withAnimation` for a motion token. Pass the view's `accessibilityReduceMotion` value.
@MainActor
public func withNookAnimation<Result>(_ motion: NookMotion, reduceMotion: Bool,
                                      _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(motion.animation(reduceMotion: reduceMotion), body)
}
