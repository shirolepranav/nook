import SwiftUI
import UIKit

// Color tokens (03 §2). Each name is a color set in Resources/Colors.xcassets, generated
// from 03 by design/tools/export_colorsets.py with Light, Dark and High Contrast variants,
// so SwiftUI picks the right one from the environment. Never edit the color sets by hand.

/// Neutral, surface and semantic colors (03 §2.1, §2.4).
public enum NookColor {
    public static let canvas = named("canvas")                 // app background
    public static let surface = named("surface")               // cards, rows
    public static let surfaceRaised = named("surfaceRaised")   // toasts, answer cards, popovers
    public static let surfaceSunken = named("surfaceSunken")   // text-field wells, photo placeholders
    public static let hairline = named("hairline")             // card borders, dividers
    public static let hairlineStrong = named("hairlineStrong") // dashed "add" cards
    public static let textPrimary = named("textPrimary")
    public static let textSecondary = named("textSecondary")   // also placeholders (D24)
    public static let textTertiary = named("textTertiary")     // disabled and decorative only (D24)
    public static let success = named("success")
    public static let warning = named("warning")
    public static let danger = named("danger")
    public static let info = named("info")
    /// Behind a live camera feed, in both modes (C-02, C-05, C-08): the feed is the content,
    /// and glass controls float on it (03 §6.3).
    public static let cameraFeed = Color.black

    static func named(_ name: String) -> Color { Color(name, bundle: .module) }
}

/// The accent the user picks in Appearance (S-06). Terracotta is the default (D5).
public enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case terracotta, sage, ocean, plum, slate, rose

    public var id: String { rawValue }

    /// Buttons, selection, the Capture button. Applied app-wide with `.tint(accent.color)`.
    public var color: Color { NookColor.named("Accent/\(rawValue)") }

    /// Text and icons drawn on an accent fill.
    public var onAccent: Color { NookColor.named("OnAccent/\(rawValue)") }

    /// Background of suggested (AI-filled) fields: the accent at 12% light, 18% dark (03 §2.4).
    public var suggested: Color {
        let accent = UIColor(named: "Accent/\(rawValue)", in: .module, compatibleWith: nil) ?? .tintColor
        return Color(uiColor: UIColor { traits in
            accent.resolvedColor(with: traits).withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.18 : 0.12)
        })
    }
}

/// A room's soft color (03 §2.3). Text on a fill uses `textPrimary`/`textSecondary`;
/// the room's symbol uses `ink`.
public enum RoomColor: String, CaseIterable, Identifiable, Sendable {
    case clay, sage, sky, lavender, butter, rose, stone, mint

    public var id: String { rawValue }
    public var fill: Color { NookColor.named("Room/\(rawValue)Fill") }
    public var ink: Color { NookColor.named("Room/\(rawValue)Ink") }
}
