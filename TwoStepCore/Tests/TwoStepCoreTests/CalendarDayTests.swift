import Testing
@testable import TwoStepCore

@Suite("CalendarDay — civil-calendar arithmetic")
struct CalendarDayTests {
    @Test("Parses valid dates and round-trips the canonical string")
    func parsingRoundTrip() {
        for string in ["1970-01-01", "2024-02-29", "2026-08-26", "2026-12-31", "2000-02-29"] {
            let day = CalendarDay(dateString: string)
            #expect(day != nil)
            #expect(day?.dateString == string)
        }
    }

    @Test("Rejects malformed and impossible dates")
    func rejectsInvalid() {
        for string in ["2026-02-29", "2026-04-31", "2026-13-01", "2026-00-10",
                       "26-08-26", "2026/08/26", "2026-8-26", "", "2026-08-00"] {
            #expect(CalendarDay(dateString: string) == nil, "\(string) should be invalid")
        }
    }

    @Test("Day number epoch and inverse round-trip")
    func dayNumberRoundTrip() {
        let epoch = CalendarDay(dateString: "1970-01-01")
        #expect(epoch?.dayNumber == 0)
        for string in ["1969-12-31", "1970-01-02", "2000-03-01", "2024-02-29", "2026-08-26", "2100-01-01"] {
            guard let day = CalendarDay(dateString: string) else {
                Issue.record("failed to parse \(string)")
                continue
            }
            #expect(CalendarDay(dayNumber: day.dayNumber) == day)
        }
        #expect(CalendarDay(dateString: "1969-12-31")?.dayNumber == -1)
    }

    @Test("Weekday index: Monday = 0 through Sunday = 6")
    func weekdays() {
        // 1970-01-01 was a Thursday.
        #expect(CalendarDay(dateString: "1970-01-01")?.weekdayIndexFromMonday == 3)
        // 2026-08-24 was a Monday; the 26th a Wednesday; the 30th a Sunday.
        #expect(CalendarDay(dateString: "2026-08-24")?.weekdayIndexFromMonday == 0)
        #expect(CalendarDay(dateString: "2026-08-26")?.weekdayIndexFromMonday == 2)
        #expect(CalendarDay(dateString: "2026-08-30")?.weekdayIndexFromMonday == 6)
        // Pre-epoch date stays in range.
        #expect(CalendarDay(dateString: "1969-12-28")?.weekdayIndexFromMonday == 6)
    }

    @Test("Adding days crosses month, year, and leap boundaries")
    func addingDays() {
        #expect(CalendarDay(dateString: "2026-08-31")?.adding(days: 1).dateString == "2026-09-01")
        #expect(CalendarDay(dateString: "2026-12-31")?.adding(days: 1).dateString == "2027-01-01")
        #expect(CalendarDay(dateString: "2024-02-28")?.adding(days: 1).dateString == "2024-02-29")
        #expect(CalendarDay(dateString: "2026-02-28")?.adding(days: 1).dateString == "2026-03-01")
        #expect(CalendarDay(dateString: "2026-01-01")?.adding(days: -1).dateString == "2025-12-31")
    }

    @Test("Difference and ordering")
    func differenceAndOrdering() {
        guard let earlier = CalendarDay(dateString: "2026-08-20"),
              let later = CalendarDay(dateString: "2026-08-23")
        else {
            Issue.record("parse failure")
            return
        }
        #expect(later.days(since: earlier) == 3)
        #expect(earlier.days(since: later) == -3)
        #expect(earlier < later)
        #expect(!(later < earlier))
    }
}
