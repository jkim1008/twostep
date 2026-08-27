import Foundation
import TwoStepCore

/// Rescopes the bills calendar (PRD §4.6): the toggle drives both the grid
/// and the agenda beneath, which always cover the identical visible period.
enum RecurringCalendarScope: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }
}

/// One rendered entry on the bills calendar: a predicted upcoming charge, a
/// paid one (an imported transaction linked via `recurringItemId`), or a
/// paused item's dimmed placeholder.
struct BillOccurrence: Identifiable, Hashable {
    enum State: Hashable {
        case upcoming
        case paid
        case paused
    }

    let id: String
    let itemId: String
    let merchant: String
    let amountMinor: Int
    /// Canonical `"YYYY-MM-DD"` day this occurrence lands on.
    let date: String
    let state: State
    let attributedTo: Attribution
    let accountId: String?
    let categoryId: String?
}

/// Pure scoping + occurrence assembly for the calendar. All date arithmetic
/// delegates to `TwoStepCore` (`CalendarDay`, `MonthKey`, `RecurrenceEngine`);
/// nothing here re-implements recurrence math.
enum RecurringCalendarModel {
    // MARK: Visible period

    /// Inclusive visible period for a scope anchored at a day.
    static func period(
        for scope: RecurringCalendarScope,
        anchor: CalendarDay
    ) -> (start: CalendarDay, end: CalendarDay) {
        switch scope {
        case .day:
            return (anchor, anchor)
        case .week:
            let monday = anchor.adding(days: -anchor.weekdayIndexFromMonday)
            return (monday, monday.adding(days: 6))
        case .month:
            let first = day(year: anchor.year, month: anchor.month, day: 1, fallback: anchor)
            let lastDay = MonthKey.daysIn(month: anchor.month, year: anchor.year)
            let last = day(year: anchor.year, month: anchor.month, day: lastDay, fallback: anchor)
            return (first, last)
        }
    }

    /// The anchor moved by whole periods (±1 chevron step).
    static func advance(
        _ anchor: CalendarDay,
        by scope: RecurringCalendarScope,
        steps: Int
    ) -> CalendarDay {
        switch scope {
        case .day:
            return anchor.adding(days: steps)
        case .week:
            return anchor.adding(days: steps * 7)
        case .month:
            let zeroBased = anchor.year * 12 + (anchor.month - 1) + steps
            let year = zeroBased >= 0 ? zeroBased / 12 : (zeroBased - 11) / 12
            let month = zeroBased - year * 12 + 1
            let clamped = min(anchor.day, MonthKey.daysIn(month: month, year: year))
            return day(year: year, month: month, day: clamped, fallback: anchor)
        }
    }

    /// The month grid as Monday-first rows of seven; nil pads days outside
    /// the anchor's month.
    static func monthGridWeeks(anchor: CalendarDay) -> [[CalendarDay?]] {
        let (first, last) = period(for: .month, anchor: anchor)
        var cells: [CalendarDay?] = Array(repeating: nil, count: first.weekdayIndexFromMonday)
        for offset in 0...last.days(since: first) {
            cells.append(first.adding(days: offset))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    // MARK: Occurrences

    /// Every occurrence in the inclusive period, date-ordered: paid ones from
    /// linked transactions, upcoming ones from `RecurrenceEngine`, and paused
    /// items as dimmed placeholders on their held due date.
    static func occurrences(
        items: [RecurringItem],
        transactions: [Transaction],
        from start: CalendarDay,
        to end: CalendarDay
    ) -> [BillOccurrence] {
        var result = paidOccurrences(items: items, transactions: transactions, from: start, to: end)
        let paidKeys = Set(result.map { "\($0.itemId)|\($0.date)" })
        for item in items {
            if item.isPaused {
                if let due = CalendarDay(dateString: item.nextDueDate),
                   due >= start, due <= end, !paidKeys.contains("\(item.id)|\(item.nextDueDate)") {
                    result.append(occurrence(of: item, on: item.nextDueDate, state: .paused))
                }
                continue
            }
            let dueDates = RecurrenceEngine.occurrences(
                of: item,
                fromDate: start.dateString,
                toDate: end.dateString
            )
            for dueDate in dueDates where !paidKeys.contains("\(item.id)|\(dueDate)") {
                result.append(occurrence(of: item, on: dueDate, state: .upcoming))
            }
        }
        return result.sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date < rhs.date : lhs.merchant < rhs.merchant
        }
    }

    /// Occurrences grouped by day for grid cell chips.
    static func occurrencesByDate(_ occurrences: [BillOccurrence]) -> [String: [BillOccurrence]] {
        Dictionary(grouping: occurrences, by: \.date)
    }

    // MARK: - Private

    private static func paidOccurrences(
        items: [RecurringItem],
        transactions: [Transaction],
        from start: CalendarDay,
        to end: CalendarDay
    ) -> [BillOccurrence] {
        transactions.compactMap { transaction in
            guard let itemId = transaction.recurringItemId,
                  let day = CalendarDay(dateString: transaction.date),
                  day >= start, day <= end,
                  let item = items.first(where: { $0.id == itemId })
            else { return nil }
            return BillOccurrence(
                id: "paid-\(transaction.id)",
                itemId: itemId,
                merchant: item.merchant,
                amountMinor: transaction.amountMinor,
                date: transaction.date,
                state: .paid,
                attributedTo: item.attributedTo,
                accountId: transaction.accountId ?? item.accountId,
                categoryId: item.categoryId
            )
        }
    }

    private static func occurrence(
        of item: RecurringItem,
        on date: String,
        state: BillOccurrence.State
    ) -> BillOccurrence {
        BillOccurrence(
            id: "\(state == .paused ? "paused" : "due")-\(item.id)-\(date)",
            itemId: item.id,
            merchant: item.merchant,
            amountMinor: item.amountMinor,
            date: date,
            state: state,
            attributedTo: item.attributedTo,
            accountId: item.accountId,
            categoryId: item.categoryId
        )
    }

    private static func day(year: Int, month: Int, day dayValue: Int, fallback: CalendarDay) -> CalendarDay {
        let dateString = String(format: "%04d-%02d-%02d", year, month, dayValue)
        return CalendarDay(dateString: dateString) ?? fallback
    }
}
