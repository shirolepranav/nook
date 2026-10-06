import SwiftUI

/// What the shell shows: the four tabs (D2), or on regular width a room picked in the
/// sidebar (01 §1.1). Capture is a floating action, not a tab (D26). Stored as text so
/// `@SceneStorage` keeps it across relaunches and window resizes.
enum AppTab: Hashable, RawRepresentable {
    case home, find, reports, settings
    case room(UUID)

    init?(rawValue: String) {
        switch rawValue {
        case "home": self = .home
        case "find": self = .find
        case "reports": self = .reports
        case "settings": self = .settings
        default:
            guard rawValue.hasPrefix("room:"), let id = UUID(uuidString: String(rawValue.dropFirst(5))) else {
                return nil
            }
            self = .room(id)
        }
    }

    var rawValue: String {
        switch self {
        case .home: "home"
        case .find: "find"
        case .reports: "reports"
        case .settings: "settings"
        case .room(let id): "room:\(id.uuidString)"
        }
    }
}

extension FocusedValues {
    /// Lets the menu-bar commands (NookCommands) switch tabs in the focused window.
    @Entry var selectedTab: Binding<AppTab>?
    /// Set while a room is selected in the sidebar; ⌘E turns it on to edit that room.
    @Entry var editsSelectedRoom: Binding<Bool>?
}
