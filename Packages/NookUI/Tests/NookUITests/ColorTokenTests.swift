import Testing
import UIKit
@testable import NookUI

// Every token in 03 §2 must exist in the catalog and resolve in every appearance.
// Values are checked against 03 by design/tools/check_tokens.py; this checks the wiring.

private let neutrals = ["canvas", "surface", "surfaceRaised", "surfaceSunken", "hairline", "hairlineStrong",
                        "textPrimary", "textSecondary", "textTertiary", "success", "warning", "danger", "info"]
private let accents = AccentChoice.allCases.flatMap { ["Accent/\($0.rawValue)", "OnAccent/\($0.rawValue)"] }
private let rooms = RoomColor.allCases.flatMap { ["Room/\($0.rawValue)Fill", "Room/\($0.rawValue)Ink"] }

@MainActor private func traits(dark: Bool, highContrast: Bool) -> UITraitCollection {
    UITraitCollection { t in
        t.userInterfaceStyle = dark ? .dark : .light
        t.accessibilityContrast = highContrast ? .high : .normal
    }
}

@MainActor private func rgb(_ name: String, _ traits: UITraitCollection) -> [CGFloat]? {
    guard let color = UIColor(named: name, in: .module, compatibleWith: traits) else { return nil }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
    return [r, g, b].map { ($0 * 255).rounded() }
}

@MainActor @Test(arguments: neutrals + accents + rooms)
func tokenResolvesInEveryAppearance(name: String) {
    for dark in [false, true] {
        for highContrast in [false, true] {
            #expect(rgb(name, traits(dark: dark, highContrast: highContrast)) != nil, "\(name)")
        }
    }
}

@MainActor @Test func darkAndHighContrastVariantsAreUsed() {
    // canvas: #F7F3EE light, #1B1714 dark (03 §2.1)
    #expect(rgb("canvas", traits(dark: false, highContrast: false)) == [0xF7, 0xF3, 0xEE])
    #expect(rgb("canvas", traits(dark: true, highContrast: false)) == [0x1B, 0x17, 0x14])
    // textSecondary HC light: #534A43
    #expect(rgb("textSecondary", traits(dark: false, highContrast: true)) == [0x53, 0x4A, 0x43])
    // Terracotta HC dark: #EEA383 (03 §2.2)
    #expect(rgb("Accent/terracotta", traits(dark: true, highContrast: true)) == [0xEE, 0xA3, 0x83])
}

@Test func defaultAccentIsTerracotta() {
    // D5. AccentChoice's first case is the default the app stores.
    #expect(AccentChoice.allCases.first == .terracotta)
}
