import Foundation

/// Advancing recurring items through time (PRD §4.6).
///
/// Rules:
/// - `weekly` adds 7 days, `biweekly` 14 — never crosses a clamping concern.
/// - `monthly` adds one calendar month, clamping the day to the target
///   month's length (Jan 31 → Feb 28, or Feb 29 in a leap year).
/// - `yearly` adds one year with the same clamp (Feb 29 → Feb 28 off-leap).
/// - Clamping is not anchor-preserving: once clamped to Feb 28, subsequent
///   months advance from the 28th. `nextDueDate` is the only stored state.
/// - Paused items neither auto-log nor forecast. End-dated items expire
///   silently: no occurrence is ever produced after `endDate`.
public enum RecurrenceEngine {
    /// The due date after `dateString` for the given frequency, with month-end
    /// clamping. Nil for malformed input.
    public static func nextDueDate(
        after dateString: String,
        frequency: RecurringItem.Frequency
    ) -> String? {
        guard let day = CalendarDay(dateString: dateString) else { return nil }
        return switch frequency {
        case .weekly: day.adding(days: 7).dateString
        case .biweekly: day.adding(days: 14).dateString
        case .monthly: addingMonths(1, to: day).dateString
        case .yearly: addingYears(1, to: day).dateString
        }
    }

    /// The item after one occurrence fires: `nextDueDate` advanced once.
    /// Returns nil when the item shouldn't advance (paused, malformed date) or
    /// when the advanced date passes `endDate` (the item has expired — callers
    /// treat nil as "no future occurrence").
    public static func advanced(_ item: RecurringItem) -> RecurringItem? {
        guard !item.isPaused,
              let next = nextDueDate(after: item.nextDueDate, frequency: item.frequency)
        else { return nil }
        if let endDate = item.endDate,
           let endDay = CalendarDay(dateString: endDate),
           let nextDay = CalendarDay(dateString: next),
           nextDay > endDay {
            return nil
        }
        var advanced = item
        advanced.nextDueDate = next
        return advanced
    }

    /// Whether the daily engine should auto-create a transaction for this item
    /// on `dateString`. Defensively re-checks the cash-only invariant via
    /// `cashAccountIds`.
    public static func shouldAutoLog(
        _ item: RecurringItem,
        on dateString: String,
        cashAccountIds: Set<String>
    ) -> Bool {
        guard item.autoLog,
              !item.isPaused,
              let accountId = item.accountId,
              cashAccountIds.contains(accountId),
              let day = CalendarDay(dateString: dateString),
              let due = CalendarDay(dateString: item.nextDueDate),
              day == due
        else { return false }
        if let endDate = item.endDate, let endDay = CalendarDay(dateString: endDate) {
            return due <= endDay
        }
        return true
    }

    /// All occurrence dates of `item` in `fromDate...toDate` (inclusive), as
    /// date strings in order. Empty when paused, malformed, or out of range;
    /// truncated at `endDate`. Powers the upcoming-bills forecast.
    public static func occurrences(
        of item: RecurringItem,
        fromDate: String,
        toDate: String
    ) -> [String] {
        guard !item.isPaused,
              let from = CalendarDay(dateString: fromDate),
              let to = CalendarDay(dateString: toDate),
              from <= to,
              var cursor = CalendarDay(dateString: item.nextDueDate)
        else { return [] }
        let endDay = item.endDate.flatMap(CalendarDay.init(dateString:))
        var result: [String] = []
        while cursor <= to {
            if let endDay, cursor > endDay { break }
            if cursor >= from {
                result.append(cursor.dateString)
            }
            guard let next = nextDueDate(after: cursor.dateString, frequency: item.frequency),
                  let nextDay = CalendarDay(dateString: next)
            else { break }
            cursor = nextDay
        }
        return result
    }

    // MARK: - Private

    private static func addingMonths(_ months: Int, to day: CalendarDay) -> CalendarDay {
        let zeroBased = day.year * 12 + (day.month - 1) + months
        let year = zeroBased >= 0 ? zeroBased / 12 : (zeroBased - 11) / 12
        let month = zeroBased - year * 12 + 1
        let clampedDay = min(day.day, MonthKey.daysIn(month: month, year: year))
        guard let result = CalendarDay(
            dateString: String(format: "%04d-%02d-%02d", year, month, clampedDay)
        ) else {
            // Unreachable: components are valid by construction.
            return day
        }
        return result
    }

    private static func addingYears(_ years: Int, to day: CalendarDay) -> CalendarDay {
        let year = day.year + years
        let clampedDay = min(day.day, MonthKey.daysIn(month: day.month, year: year))
        guard let result = CalendarDay(
            dateString: String(format: "%04d-%02d-%02d", year, day.month, clampedDay)
        ) else {
            return day
        }
        return result
    }
}
