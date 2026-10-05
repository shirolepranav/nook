import SwiftUI
import NookUI

/// The four tabs (D2). Capture is a floating action, not a tab (D26).
enum AppTab: String, CaseIterable {
    case home, find, reports, settings
}

extension FocusedValues {
    /// Lets the menu-bar commands (NookCommands) switch tabs in the focused window.
    @Entry var selectedTab: Binding<AppTab>?
    #if DEBUG
    /// P1 hardware-keyboard check of ⌘⌫ (D30): the command shows a toast. Removed when the
    /// phase closes.
    @Entry var shortcutToast: Binding<ToastMessage?>?
    #endif
}
