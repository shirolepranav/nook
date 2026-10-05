import SwiftUI

/// Haptic tokens (03 §10). Haptics never carry meaning alone: every event also changes
/// something on screen. They stay on under Reduce Motion.
public enum NookHaptic: Sendable {
    /// Saved, purchase complete, unlock success, move confirmed. Only on real success.
    case saved
    /// Picker, chip, segment.
    case selected
    /// Outline appears, code recognized, photo taken.
    case tick
    /// Unlock failed, validation error.
    case failed

    public var feedback: SensoryFeedback {
        switch self {
        case .saved: .success
        case .selected: .selection
        case .tick: .impact(weight: .light)
        case .failed: .error
        }
    }
}

public extension View {
    /// Plays a haptic token whenever `trigger` changes.
    func nookHaptic(_ haptic: NookHaptic, trigger: some Equatable) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }
}
