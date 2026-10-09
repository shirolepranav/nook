import Foundation

/// Warranty dates (F4, D21). An item can hold several warranties; the screens show the one
/// that ends last (D50).
public enum Warranties {
    /// D13, D21.
    public static let defaultOffsets = [30, 7]

    /// The purchase date plus the length, in whole months. A Feb 29 start plus a year ends
    /// Feb 28, and Jan 31 plus a month ends on the last day of February (`Calendar`'s rule).
    public static func endDate(start: Date, lengthMonths: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .month, value: lengthMonths, to: calendar.startOfDay(for: start))
    }

    /// Whole calendar days from today to the end; negative once it has ended.
    public static func daysLeft(until end: Date, now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
    }
}

extension Warranty {
    /// R-04's swipe and the editor turn the 30- and 7-day reminders on or off.
    public var remindersOn: Bool {
        get { !reminderOffsetsDays.isEmpty }
        set { reminderOffsetsDays = newValue ? Warranties.defaultOffsets : [] }
    }
}

extension Item {
    /// The warranty that ends last; the one I-01, I-02 and R-04 show (D21, D50).
    public var primaryWarranty: Warranty? {
        (warranties ?? []).filter { $0.endDate != nil }.max { $0.endDate! < $1.endDate! }
    }

    /// The loan that's still out, if any (F7).
    public var activeLoan: Loan? {
        (loans ?? []).filter { $0.returnedAt == nil }.max { $0.lentAt < $1.lentAt }
    }
}
