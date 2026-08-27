import Testing
@testable import TwoStepCore

@Suite("RecurrenceEngine — due-date advancement")
struct RecurrenceEngineTests {
    private func item(
        frequency: RecurringItem.Frequency = .monthly,
        nextDueDate: String = "2026-08-31",
        accountId: String? = "acct-cash",
        autoLog: Bool = false,
        isPaused: Bool = false,
        endDate: String? = nil
    ) -> RecurringItem {
        RecurringItem(
            id: "rec-1",
            merchant: "Rent",
            amountMinor: 250000,
            frequency: frequency,
            nextDueDate: nextDueDate,
            attributedTo: .joint,
            accountId: accountId,
            autoLog: autoLog,
            isPaused: isPaused,
            endDate: endDate
        )
    }

    // MARK: - nextDueDate

    @Test("Weekly and biweekly add plain days")
    func weeklyBiweekly() {
        #expect(RecurrenceEngine.nextDueDate(after: "2026-08-26", frequency: .weekly) == "2026-09-02")
        #expect(RecurrenceEngine.nextDueDate(after: "2026-08-26", frequency: .biweekly) == "2026-09-09")
        #expect(RecurrenceEngine.nextDueDate(after: "2026-12-28", frequency: .weekly) == "2027-01-04")
    }

    @Test("Monthly clamps to the target month's end")
    func monthlyClamping() {
        #expect(RecurrenceEngine.nextDueDate(after: "2026-01-31", frequency: .monthly) == "2026-02-28")
        #expect(RecurrenceEngine.nextDueDate(after: "2024-01-31", frequency: .monthly) == "2024-02-29") // leap
        #expect(RecurrenceEngine.nextDueDate(after: "2026-08-31", frequency: .monthly) == "2026-09-30")
        #expect(RecurrenceEngine.nextDueDate(after: "2026-03-31", frequency: .monthly) == "2026-04-30")
        #expect(RecurrenceEngine.nextDueDate(after: "2026-08-15", frequency: .monthly) == "2026-09-15")
    }

    @Test("Monthly crosses the year boundary")
    func monthlyYearBoundary() {
        #expect(RecurrenceEngine.nextDueDate(after: "2026-12-15", frequency: .monthly) == "2027-01-15")
        #expect(RecurrenceEngine.nextDueDate(after: "2026-12-31", frequency: .monthly) == "2027-01-31")
    }

    @Test("Clamping is not anchor-preserving: once on the 28th, stays on the 28th")
    func clampNotAnchorPreserving() {
        #expect(RecurrenceEngine.nextDueDate(after: "2026-02-28", frequency: .monthly) == "2026-03-28")
    }

    @Test("Yearly clamps Feb 29 to Feb 28 off-leap")
    func yearly() {
        #expect(RecurrenceEngine.nextDueDate(after: "2024-02-29", frequency: .yearly) == "2025-02-28")
        #expect(RecurrenceEngine.nextDueDate(after: "2026-06-15", frequency: .yearly) == "2027-06-15")
    }

    @Test("Malformed dates advance to nil")
    func malformed() {
        #expect(RecurrenceEngine.nextDueDate(after: "2026-02-30", frequency: .monthly) == nil)
        #expect(RecurrenceEngine.nextDueDate(after: "junk", frequency: .weekly) == nil)
    }

    // MARK: - advanced(_:)

    @Test("Advancing an active item moves nextDueDate one period")
    func advanceActive() {
        let advanced = RecurrenceEngine.advanced(item(nextDueDate: "2026-08-31"))
        #expect(advanced?.nextDueDate == "2026-09-30")
    }

    @Test("Paused items never advance")
    func advancePaused() {
        #expect(RecurrenceEngine.advanced(item(isPaused: true)) == nil)
    }

    @Test("End-dated items expire silently at the boundary")
    func advanceEndDated() {
        // Next occurrence 2026-09-30 lands after endDate → expired.
        #expect(RecurrenceEngine.advanced(item(endDate: "2026-09-29")) == nil)
        // Next occurrence exactly on endDate is still valid.
        #expect(RecurrenceEngine.advanced(item(endDate: "2026-09-30"))?.nextDueDate == "2026-09-30")
    }

    // MARK: - shouldAutoLog

    @Test("Auto-log fires only for a due, unpaused, cash-account item")
    func autoLogHappyPath() {
        let cash: Set<String> = ["acct-cash"]
        let due = item(autoLog: true)
        #expect(RecurrenceEngine.shouldAutoLog(due, on: "2026-08-31", cashAccountIds: cash))
        #expect(!RecurrenceEngine.shouldAutoLog(due, on: "2026-08-30", cashAccountIds: cash)) // not due yet
        #expect(!RecurrenceEngine.shouldAutoLog(due, on: "2026-09-01", cashAccountIds: cash)) // past due date
    }

    @Test("Auto-log decision table: flag off, paused, linked account, no account, expired")
    func autoLogGuards() {
        let cash: Set<String> = ["acct-cash"]
        #expect(!RecurrenceEngine.shouldAutoLog(
            item(autoLog: false), on: "2026-08-31", cashAccountIds: cash))
        #expect(!RecurrenceEngine.shouldAutoLog(
            item(autoLog: true, isPaused: true), on: "2026-08-31", cashAccountIds: cash))
        // Cash-only invariant re-checked defensively: linked account never auto-logs.
        #expect(!RecurrenceEngine.shouldAutoLog(
            item(accountId: "acct-chase", autoLog: true), on: "2026-08-31", cashAccountIds: cash))
        #expect(!RecurrenceEngine.shouldAutoLog(
            item(accountId: nil, autoLog: true), on: "2026-08-31", cashAccountIds: cash))
        // Due date already past the end date.
        #expect(!RecurrenceEngine.shouldAutoLog(
            item(autoLog: true, endDate: "2026-08-30"), on: "2026-08-31", cashAccountIds: cash))
    }

    // MARK: - occurrences

    @Test("Occurrences enumerate due dates inside the window")
    func occurrencesWindow() {
        let netflix = item(frequency: .weekly, nextDueDate: "2026-08-26")
        let dates = RecurrenceEngine.occurrences(
            of: netflix, fromDate: "2026-08-24", toDate: "2026-09-08")
        #expect(dates == ["2026-08-26", "2026-09-02"])
    }

    @Test("Occurrences respect pause, end date, and empty windows")
    func occurrencesGuards() {
        #expect(RecurrenceEngine.occurrences(
            of: item(frequency: .weekly, nextDueDate: "2026-08-26", isPaused: true),
            fromDate: "2026-08-24", toDate: "2026-09-08") == [])
        #expect(RecurrenceEngine.occurrences(
            of: item(frequency: .weekly, nextDueDate: "2026-08-26", endDate: "2026-08-30"),
            fromDate: "2026-08-24", toDate: "2026-09-08") == ["2026-08-26"])
        // Next due after the window → nothing.
        #expect(RecurrenceEngine.occurrences(
            of: item(frequency: .weekly, nextDueDate: "2026-09-09"),
            fromDate: "2026-08-24", toDate: "2026-09-08") == [])
        // Inverted window → nothing.
        #expect(RecurrenceEngine.occurrences(
            of: item(frequency: .weekly, nextDueDate: "2026-08-26"),
            fromDate: "2026-09-08", toDate: "2026-08-24") == [])
    }

    @Test("Monthly occurrences carry the clamp forward")
    func occurrencesMonthlyClamp() {
        let rent = item(frequency: .monthly, nextDueDate: "2026-08-31")
        let dates = RecurrenceEngine.occurrences(
            of: rent, fromDate: "2026-08-01", toDate: "2026-11-01")
        #expect(dates == ["2026-08-31", "2026-09-30", "2026-10-30"])
    }
}
