import Foundation

/// The currency new items start in and Home totals use (D41): the region's, until Settings
/// has a picker. In NookKit so the widgets total the same way.
public enum HomeCurrency {
    public static var code: String { Locale.current.currency?.identifier ?? "USD" }
}
