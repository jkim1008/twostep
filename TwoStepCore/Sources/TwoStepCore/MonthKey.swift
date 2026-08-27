import Foundation

/// Calendar-month bucketing over day-precision `"YYYY-MM-DD"` date strings.
///
/// Transactions carry their date as a plain calendar string, so month
/// assignment is pure string logic — no timezone drift, fully unit-testable.
/// This is the single boundary function all budget math consumes.
public enum MonthKey {
    /// `"2026-08-26"` → `"2026-08"`. Returns nil for malformed or impossible dates.
    public static func key(forDateString dateString: String) -> String? {
        guard let date = parsed(dateString),
              (1...12).contains(date.month),
              (1...daysIn(month: date.month, year: date.year)).contains(date.day)
        else { return nil }
        return String(format: "%04d-%02d", date.year, date.month)
    }

    /// `"2026-12"` → `"2027-01"`. Returns nil for malformed keys.
    public static func next(_ monthKey: String) -> String? {
        guard let (year, month) = monthComponents(of: monthKey) else { return nil }
        return month == 12
            ? String(format: "%04d-01", year + 1)
            : String(format: "%04d-%02d", year, month + 1)
    }

    /// `"2027-01"` → `"2026-12"`. Returns nil for malformed keys.
    public static func previous(_ monthKey: String) -> String? {
        guard let (year, month) = monthComponents(of: monthKey) else { return nil }
        return month == 1
            ? String(format: "%04d-12", year - 1)
            : String(format: "%04d-%02d", year, month - 1)
    }

    /// Number of days in a month, honoring leap years.
    public static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    // MARK: - Parsing

    private struct ParsedDate {
        let year: Int
        let month: Int
        let day: Int
    }

    private static func parsed(_ dateString: String) -> ParsedDate? {
        let parts = dateString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        return ParsedDate(year: year, month: month, day: day)
    }

    private static func monthComponents(of monthKey: String) -> (year: Int, month: Int)? {
        let parts = monthKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 4, parts[1].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]),
              (1...12).contains(month)
        else { return nil }
        return (year, month)
    }
}
