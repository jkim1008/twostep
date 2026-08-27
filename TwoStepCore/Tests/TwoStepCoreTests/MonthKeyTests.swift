import Testing
@testable import TwoStepCore

@Suite("MonthKey — calendar month bucketing")
struct MonthKeyTests {
    @Test("Extracts month key from valid date strings")
    func validDates() {
        #expect(MonthKey.key(forDateString: "2026-08-26") == "2026-08")
        #expect(MonthKey.key(forDateString: "2026-01-01") == "2026-01")
        #expect(MonthKey.key(forDateString: "2026-12-31") == "2026-12")
    }

    @Test("Rejects malformed and impossible dates")
    func invalidDates() {
        #expect(MonthKey.key(forDateString: "2026-13-01") == nil)   // month 13
        #expect(MonthKey.key(forDateString: "2026-02-29") == nil)   // 2026 is not a leap year
        #expect(MonthKey.key(forDateString: "2026-04-31") == nil)   // April has 30 days
        #expect(MonthKey.key(forDateString: "26-08-26") == nil)     // 2-digit year
        #expect(MonthKey.key(forDateString: "2026/08/26") == nil)   // wrong separator
        #expect(MonthKey.key(forDateString: "") == nil)
    }

    @Test("Leap-year February boundary")
    func leapYears() {
        #expect(MonthKey.key(forDateString: "2024-02-29") == "2024-02")  // leap year
        #expect(MonthKey.daysIn(month: 2, year: 2024) == 29)
        #expect(MonthKey.daysIn(month: 2, year: 2026) == 28)
        #expect(MonthKey.isLeapYear(2000))                                // divisible by 400
        #expect(!MonthKey.isLeapYear(1900))                               // divisible by 100, not 400
    }

    @Test("Year rollover in both directions")
    func yearRollover() {
        #expect(MonthKey.next("2026-12") == "2027-01")
        #expect(MonthKey.next("2026-08") == "2026-09")
        #expect(MonthKey.previous("2027-01") == "2026-12")
        #expect(MonthKey.previous("2026-08") == "2026-07")
        #expect(MonthKey.next("2026-13") == nil)
    }
}
