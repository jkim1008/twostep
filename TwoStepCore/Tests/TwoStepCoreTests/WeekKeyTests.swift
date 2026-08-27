import Testing
@testable import TwoStepCore

@Suite("WeekKey — ISO Monday–Sunday week bucketing")
struct WeekKeyTests {
    @Test("Every day of one Monday–Sunday week maps to the same key")
    func wholeWeekSameKey() {
        // 2026-08-24 (Mon) … 2026-08-30 (Sun).
        for day in 24...30 {
            #expect(WeekKey.key(forDateString: "2026-08-\(day)") == "2026-W35")
        }
        // The adjacent Sunday/Monday fall in different weeks.
        #expect(WeekKey.key(forDateString: "2026-08-23") == "2026-W34")
        #expect(WeekKey.key(forDateString: "2026-08-31") == "2026-W36")
    }

    @Test("Rejects malformed dates")
    func malformedDates() {
        #expect(WeekKey.key(forDateString: "2026-02-29") == nil)
        #expect(WeekKey.key(forDateString: "garbage") == nil)
        #expect(WeekKey.key(forDateString: "") == nil)
    }

    @Test("ISO year boundaries: early January can belong to the previous ISO year")
    func yearBoundaries() {
        // 2027-01-01 is a Friday; its week's Thursday is 2026-12-31 → 2026-W53.
        #expect(WeekKey.key(forDateString: "2027-01-01") == "2026-W53")
        #expect(WeekKey.key(forDateString: "2027-01-03") == "2026-W53")  // Sunday
        #expect(WeekKey.key(forDateString: "2027-01-04") == "2027-W01")  // Monday
        // 2021-01-01 (Friday) belonged to 2020-W53.
        #expect(WeekKey.key(forDateString: "2021-01-01") == "2020-W53")
        #expect(WeekKey.key(forDateString: "2021-01-04") == "2021-W01")
        // 2024-01-01 was a Monday → cleanly W01.
        #expect(WeekKey.key(forDateString: "2024-01-01") == "2024-W01")
        // 2023-12-31 (Sunday) stayed in 2023's final week.
        #expect(WeekKey.key(forDateString: "2023-12-31") == "2023-W52")
    }

    @Test("Start and end dates of a key")
    func startAndEnd() {
        #expect(WeekKey.startDateString(of: "2026-W35") == "2026-08-24")
        #expect(WeekKey.endDateString(of: "2026-W35") == "2026-08-30")
        // W01 of 2026 starts in December 2025 (Jan 1 2026 is a Thursday).
        #expect(WeekKey.startDateString(of: "2026-W01") == "2025-12-29")
        #expect(WeekKey.endDateString(of: "2026-W01") == "2026-01-04")
    }

    @Test("Rejects malformed and out-of-range keys")
    func malformedKeys() {
        #expect(WeekKey.startDateString(of: "2026-35") == nil)      // missing W
        #expect(WeekKey.startDateString(of: "2026-W351") == nil)    // too long
        #expect(WeekKey.startDateString(of: "2026-W00") == nil)     // week 0
        #expect(WeekKey.startDateString(of: "2026-W54") == nil)     // beyond 53
        #expect(WeekKey.startDateString(of: "2025-W53") == nil)     // 2025 has 52 ISO weeks
        #expect(WeekKey.startDateString(of: "2026-W53") == "2026-12-28") // 2026 does have 53
        #expect(WeekKey.next("bogus") == nil)
        #expect(WeekKey.previous("") == nil)
    }

    @Test("Next and previous cross year boundaries correctly")
    func nextPrevious() {
        #expect(WeekKey.next("2026-W35") == "2026-W36")
        #expect(WeekKey.previous("2026-W35") == "2026-W34")
        #expect(WeekKey.next("2026-W53") == "2027-W01")
        #expect(WeekKey.previous("2027-W01") == "2026-W53")
        #expect(WeekKey.next("2025-W52") == "2026-W01")
        #expect(WeekKey.previous("2026-W01") == "2025-W52")
        // next/previous are inverses.
        for key in ["2024-W01", "2026-W53", "2026-W35"] {
            #expect(WeekKey.next(key).flatMap(WeekKey.previous) == key)
        }
    }

    @Test("Containment: inclusive Monday through Sunday")
    func containment() {
        #expect(WeekKey.week("2026-W35", containsDateString: "2026-08-24"))
        #expect(WeekKey.week("2026-W35", containsDateString: "2026-08-30"))
        #expect(!WeekKey.week("2026-W35", containsDateString: "2026-08-23"))
        #expect(!WeekKey.week("2026-W35", containsDateString: "2026-08-31"))
        #expect(!WeekKey.week("2026-W35", containsDateString: "not-a-date"))
        #expect(!WeekKey.week("bogus", containsDateString: "2026-08-24"))
    }

    @Test("Last completed week: a mid-week day and even Sunday point back one week")
    func lastCompletedWeek() {
        guard let wednesday = CalendarDay(dateString: "2026-08-26"),
              let sunday = CalendarDay(dateString: "2026-08-30"),
              let monday = CalendarDay(dateString: "2026-08-31")
        else {
            Issue.record("parse failure")
            return
        }
        // Wednesday of W35 → last completed is W34.
        #expect(WeekKey.lastCompletedWeekKey(asOf: wednesday) == "2026-W34")
        // Sunday still belongs to the in-progress W35 → still W34.
        #expect(WeekKey.lastCompletedWeekKey(asOf: sunday) == "2026-W34")
        // The following Monday completes W35.
        #expect(WeekKey.lastCompletedWeekKey(asOf: monday) == "2026-W35")
    }
}
