import SwiftUI
import NookKit
import NookUI

/// App-wide preferences (S-06), kept in the App Group's defaults so the widgets (P12) can
/// follow the accent and Hide values without a migration. `.defaultAppStorage(.nook)` at the
/// root makes every `@AppStorage` in the app and NookUI use it.
enum PreferenceKey {
    static let accent = "accentChoice"
    static let theme = "themeChoice"
    static let hideValuesByDefault = "hideValuesByDefault"
    static let hideValues = MoneyText.hideValuesKey   // the current state, toggled on Home
    /// Set once onboarding finishes (O-02); UI tests pass `-uiTestingOnboarded YES` to skip it.
    static let hasOnboarded = "hasOnboarded"
}

extension UserDefaults {
    // Falls back to .standard only if the App Group entitlement is missing (a misconfigured
    // build); widgets would then miss these until it's fixed.
    static let nook = UserDefaults(suiteName: NookKit.appGroupID) ?? .standard
}

/// System, Light or Dark (S-06).
enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

extension AccentChoice {
    /// The name in the picker and for VoiceOver.
    var title: LocalizedStringKey {
        switch self {
        case .terracotta: "Terracotta"
        case .sage: "Sage"
        case .ocean: "Ocean"
        case .plum: "Plum"
        case .slate: "Slate"
        case .rose: "Rose"
        }
    }
}

extension RoomColor {
    /// The name VoiceOver reads in the room color picker (H-04).
    var title: LocalizedStringKey {
        switch self {
        case .clay: "Clay"
        case .sage: "Sage"
        case .sky: "Sky"
        case .lavender: "Lavender"
        case .butter: "Butter"
        case .rose: "Rose"
        case .stone: "Stone"
        case .mint: "Mint"
        }
    }
}
