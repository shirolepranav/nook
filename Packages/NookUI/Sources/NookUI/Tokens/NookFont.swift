import SwiftUI

// Type tokens (03 §3). Every token is a Dynamic Type text style, so it scales to AX5.
// SF Pro Rounded for headings and totals; prices and counts use monospaced digits.
public extension Font {
    /// Tab titles, home name.
    static let nookDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Total home value.
    static let nookTotal = Font.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
    /// Item and room headers.
    static let nookTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    /// Section and card titles.
    static let nookSection = Font.system(.title3, design: .rounded, weight: .semibold)
    /// Card item names.
    static let nookHeadline = Font.headline
    /// Body text, fields.
    static let nookBody = Font.body
    /// Breadcrumbs, last confirmed.
    static let nookMeta = Font.subheadline
    /// Helper text.
    static let nookFootnote = Font.footnote
    /// Chips, badges.
    static let nookCaption = Font.caption.weight(.medium)
    /// Prices on detail screens.
    static let nookValue = Font.system(.title3, design: .rounded, weight: .semibold).monospacedDigit()
}
