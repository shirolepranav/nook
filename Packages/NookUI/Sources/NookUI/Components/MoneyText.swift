import SwiftUI

/// A price or total. Shows "••••" when Hide values is on (F11), so screens can be shared.
public struct MoneyText: View {
    /// The `@AppStorage` key for Hide values, shared with Settings (S-06) and Home.
    public static let hideValuesKey = "hideValues"

    let amount: Decimal
    let currencyCode: String
    let font: Font
    /// "$12,480" with no cents, where space is short (widgets).
    let wholeUnits: Bool

    @AppStorage(MoneyText.hideValuesKey) private var hideValues = false

    public init(_ amount: Decimal, currencyCode: String, font: Font = .nookValue, wholeUnits: Bool = false) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.font = font
        self.wholeUnits = wholeUnits
    }

    private var format: Decimal.FormatStyle.Currency {
        wholeUnits ? .currency(code: currencyCode).precision(.fractionLength(0)) : .currency(code: currencyCode)
    }

    public var body: some View {
        Group {
            if hideValues {
                Text(verbatim: "••••")
                    .accessibilityLabel(Text("Value hidden", bundle: .module))  // VoiceOver skips the dots
            } else {
                Text(amount, format: format)
                    // "649 Indian rupees", not the symbol (03 §11). Set on a wrapping element: on
                    // the Text itself, the audit reads the longer label as clipped text.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(amount, format: format.presentation(.fullName)))
            }
        }
        .font(font)
    }
}
