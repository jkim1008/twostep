import Foundation

/// ISO-8601 week bucketing (Monday–Sunday) over day-precision `"YYYY-MM-DD"`
/// date strings, producing keys of the form `"2026-W35"`.
///
/// The Weekly Sync digest is materialized per week under this key
/// (`/households/{hid}/digests/{ISO-week}`), so the key must be stable,
/// sortable within a week-based year, and computed identically everywhere.
///
/// Invariants:
/// - Weeks run Monday through Sunday inclusive.
/// - The key's year component is the ISO week-based year (the year containing
///   the week's Thursday), so year boundaries follow ISO-8601: 2027-01-01
///   (a Friday) belongs to `"2026-W53"`.
/// - `startDateString`/`endDateString` return the Monday/Sunday of the key.
public enum WeekKey {
    /// `"2026-08-26"` → `"2026-W35"`. Returns nil for malformed or impossible dates.
    public static func key(forDateString dateString: String) -> String? {
        guard let day = CalendarDay(dateString: dateString) else { return nil }
        return key(for: day)
    }

    /// Week key containing the given calendar day.
    public static func key(for day: CalendarDay) -> String {
        let monday = day.adding(days: -day.weekdayIndexFromMonday)
        let thursday = monday.adding(days: 3)
        let jan1 = CalendarDay(dayNumber: daysFromCivil(year: thursday.year, month: 1, day: 1))
        let week = thursday.days(since: jan1) / 7 + 1
        return String(format: "%04d-W%02d", thursday.year, week)
    }

    /// The Monday of the week, as a `"YYYY-MM-DD"` string. Nil for malformed keys.
    public static func startDateString(of weekKey: String) -> String? {
        monday(of: weekKey)?.dateString
    }

    /// The Sunday of the week, as a `"YYYY-MM-DD"` string. Nil for malformed keys.
    public static func endDateString(of weekKey: String) -> String? {
        monday(of: weekKey)?.adding(days: 6).dateString
    }

    /// `"2026-W53"` → `"2027-W01"` etc. Nil for malformed keys.
    public static func next(_ weekKey: String) -> String? {
        guard let monday = monday(of: weekKey) else { return nil }
        return key(for: monday.adding(days: 7))
    }

    /// `"2027-W01"` → `"2026-W53"` etc. Nil for malformed keys.
    public static func previous(_ weekKey: String) -> String? {
        guard let monday = monday(of: weekKey) else { return nil }
        return key(for: monday.adding(days: -7))
    }

    /// Whether the date string falls inside the week. False when either input
    /// is malformed.
    public static func week(_ weekKey: String, containsDateString dateString: String) -> Bool {
        guard let monday = monday(of: weekKey),
              let day = CalendarDay(dateString: dateString)
        else { return false }
        let delta = day.days(since: monday)
        return (0...6).contains(delta)
    }

    /// The most recently *completed* week as of the given day — the digest
    /// always covers a finished Monday–Sunday span, so a Sunday still belongs
    /// to the in-progress week and the previous key is returned.
    public static func lastCompletedWeekKey(asOf day: CalendarDay) -> String {
        let currentMonday = day.adding(days: -day.weekdayIndexFromMonday)
        return key(for: currentMonday.adding(days: -7))
    }

    // MARK: - Private

    /// Monday of the week named by the key, validating the key strictly
    /// (`"YYYY-Www"`, week number must exist in that ISO year).
    private static func monday(of weekKey: String) -> CalendarDay? {
        let parts = weekKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 4,
              parts[1].count == 3, parts[1].first == "W",
              let year = Int(parts[0]),
              let week = Int(parts[1].dropFirst()),
              week >= 1
        else { return nil }
        // Monday of ISO week 1 = Monday of the week containing January 4th.
        let jan4 = CalendarDay(dayNumber: daysFromCivil(year: year, month: 1, day: 4))
        let week1Monday = jan4.adding(days: -jan4.weekdayIndexFromMonday)
        let monday = week1Monday.adding(days: (week - 1) * 7)
        // Reject week numbers past the end of this ISO year (e.g. W53 in a 52-week year).
        guard key(for: monday) == String(format: "%04d-W%02d", year, week) else { return nil }
        return monday
    }

    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        var y = year
        if month <= 2 { y -= 1 }
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }
}
