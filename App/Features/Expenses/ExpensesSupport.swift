import Foundation
import TwoStepCore

/// Display-boundary formatting for the Expenses surfaces. All money and
/// calendar math stays in TwoStepCore; only strings and `Date` bridging for
/// pickers live here.
enum ExpenseFormat {
    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Minor units → localized currency string (display boundary only).
    static func money(_ amountMinor: Int) -> String {
        Money(amountMinor: amountMinor).decimalValue.formatted(.currency(code: "USD"))
    }

    /// Canonical `"YYYY-MM-DD"` string → `Date` for `DatePicker` bridging.
    static func date(fromDateString dateString: String) -> Date? {
        dayParser.date(from: dateString)
    }

    /// `Date` from a picker → canonical `"YYYY-MM-DD"` string.
    static func dateString(from date: Date) -> String {
        dayParser.string(from: date)
    }

    /// Feed section header: "Today" for the demo's pinned today, otherwise
    /// e.g. "Wed, Aug 26". Malformed strings fall back to themselves.
    static func dayHeader(_ dateString: String, today: String) -> String {
        if dateString == today { return String(localized: "Today") }
        guard let date = date(fromDateString: dateString) else { return dateString }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

/// Feed filter state (PRD §4.3): optional calendar date range plus the
/// Hidden filter that surfaces the symmetric household archive.
struct ExpenseFeedFilter: Equatable {
    /// Inclusive `"YYYY-MM-DD"` bounds; nil = unbounded on that side.
    var startDate: String?
    var endDate: String?
    /// Show archived (hidden) transactions alongside the feed.
    var showHidden = false

    var isActive: Bool { startDate != nil || endDate != nil || showHidden }

    /// Canonical date strings compare correctly as plain strings.
    func containsDate(_ dateString: String) -> Bool {
        if let startDate, dateString < startDate { return false }
        if let endDate, dateString > endDate { return false }
        return true
    }
}

/// One feed section: a calendar day and its transactions, feed-ordered.
struct ExpenseDaySection: Identifiable {
    let date: String
    let transactions: [Transaction]

    var id: String { date }
}
