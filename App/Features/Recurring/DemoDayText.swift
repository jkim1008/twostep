import Foundation
import TwoStepCore

/// Display strings for canonical `"YYYY-MM-DD"` day strings and minor-unit
/// amounts. Formatting only — all calendar arithmetic stays in `TwoStepCore`.
enum DemoDayText {
    /// Monday-first short weekday symbols ("Mon"..."Sun"), matching
    /// `CalendarDay.weekdayIndexFromMonday`.
    static var mondayFirstWeekdaySymbols: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols // Sunday-first
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// "August 2026"
    static func monthYear(of day: CalendarDay) -> String {
        let symbols = Calendar.current.monthSymbols
        let name = symbols.indices.contains(day.month - 1) ? symbols[day.month - 1] : ""
        return "\(name) \(String(day.year))"
    }

    /// "Aug 17"
    static func shortDate(_ dateString: String) -> String {
        guard let day = CalendarDay(dateString: dateString) else { return dateString }
        return "\(shortMonthName(day.month)) \(day.day)"
    }

    /// "Thu, Aug 27"
    static func weekdayShortDate(_ dateString: String) -> String {
        guard let day = CalendarDay(dateString: dateString) else { return dateString }
        let symbols = mondayFirstWeekdaySymbols
        let index = day.weekdayIndexFromMonday
        let weekday = symbols.indices.contains(index) ? symbols[index] : ""
        return "\(weekday), \(shortMonthName(day.month)) \(day.day)"
    }

    /// "Aug 17 – Aug 23"
    static func range(_ startDateString: String, _ endDateString: String) -> String {
        "\(shortDate(startDateString)) – \(shortDate(endDateString))"
    }

    /// Full currency ("$2,200.00") from minor units, display-boundary only.
    static func currency(_ amountMinor: Int, code: String = "USD") -> String {
        Money(amountMinor: amountMinor, currencyCode: code)
            .decimalValue
            .formatted(.currency(code: code))
    }

    /// Compact currency for tight calendar chips ("$18", "$2.2K").
    static func compactCurrency(_ amountMinor: Int, code: String = "USD") -> String {
        Money(amountMinor: amountMinor, currencyCode: code)
            .decimalValue
            .formatted(
                .currency(code: code)
                .notation(.compactName)
                .precision(.fractionLength(0...1))
            )
    }

    // MARK: - Private

    private static func shortMonthName(_ month: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        return symbols.indices.contains(month - 1) ? symbols[month - 1] : ""
    }
}
