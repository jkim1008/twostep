import Foundation

/// A validated calendar day parsed from a canonical `"YYYY-MM-DD"` string.
///
/// All date logic in TwoStepCore is pure civil-calendar arithmetic over these
/// day-precision strings — no `Date`, no `Calendar`, no timezone drift.
/// Day-number conversion uses Howard Hinnant's proleptic-Gregorian algorithms,
/// exact over any range this app will ever see.
///
/// Invariants:
/// - `init?(dateString:)` accepts only strictly formatted `"YYYY-MM-DD"`
///   strings naming a real calendar day (leap years honored).
/// - `dayNumber` is the count of days since 1970-01-01 (which is day 0).
/// - `dateString` round-trips: `CalendarDay(dateString: s)?.dateString == s`.
public struct CalendarDay: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(dateString: String) {
        let parts = dateString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month),
              (1...MonthKey.daysIn(month: month, year: year)).contains(day)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01 → calendar day (inverse of `dayNumber`).
    public init(dayNumber: Int) {
        let z = dayNumber + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.month = m
        self.day = d
    }

    /// Canonical `"YYYY-MM-DD"` form.
    public var dateString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Days since 1970-01-01 (1970-01-01 == 0, which was a Thursday).
    public var dayNumber: Int {
        var y = year
        if month <= 2 { y -= 1 }
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    /// 0 = Monday … 6 = Sunday.
    public var weekdayIndexFromMonday: Int {
        // Day 0 (1970-01-01) was a Thursday, i.e. 3 days after Monday.
        let z = dayNumber + 3
        return ((z % 7) + 7) % 7
    }

    public func adding(days: Int) -> CalendarDay {
        CalendarDay(dayNumber: dayNumber + days)
    }

    /// Whole days from `other` to `self` (positive when `self` is later).
    public func days(since other: CalendarDay) -> Int {
        dayNumber - other.dayNumber
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }
}
