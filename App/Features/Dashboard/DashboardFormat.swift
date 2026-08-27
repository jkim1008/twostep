import Foundation
import TwoStepCore

/// Display-boundary formatting for Dashboard modules. Math stays in
/// TwoStepCore; only strings are made here.
enum DashboardFormat {
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

    /// `"2026-09-01"` → `"Sep 1"`. Falls back to the raw string for
    /// malformed input rather than crashing.
    static func shortDate(_ dateString: String) -> String {
        guard let date = dayParser.date(from: dateString) else { return dateString }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
