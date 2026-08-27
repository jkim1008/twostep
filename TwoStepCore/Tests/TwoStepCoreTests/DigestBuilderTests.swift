import Foundation
import Testing
@testable import TwoStepCore

@Suite("DigestBuilder — Weekly Sync digest math")
struct DigestBuilderTests {
    // Week under test: 2026-W35 = Mon 2026-08-24 … Sun 2026-08-30.
    private let week = "2026-W35"

    private func txn(
        id: String,
        amountMinor: Int,
        direction: Transaction.Direction = .expense,
        date: String,
        categoryId: String? = "groceries",
        attributedTo: Attribution = .joint,
        pfcPrimary: String? = nil,
        excludeFromBudget: Bool = false,
        isHidden: Bool = false,
        splits: [Transaction.Split] = []
    ) -> Transaction {
        Transaction(
            id: id,
            source: .plaid,
            accountId: "acct-1",
            amountMinor: amountMinor,
            direction: direction,
            date: date,
            categoryId: categoryId,
            pfcPrimary: pfcPrimary,
            attributedTo: attributedTo,
            excludeFromBudget: excludeFromBudget,
            isHidden: isHidden,
            splits: splits
        )
    }

    @Test("Malformed week key produces no digest")
    func malformedWeekKey() {
        #expect(DigestBuilder.build(
            weekKey: "not-a-week", transactions: [], allocations: [:], recurringItems: []) == nil)
    }

    @Test("Empty inputs produce an all-zero digest (first-week case)")
    func emptyDigest() {
        let digest = DigestBuilder.build(
            weekKey: week, transactions: [], allocations: [:], recurringItems: [])
        #expect(digest?.startDate == "2026-08-24")
        #expect(digest?.endDate == "2026-08-30")
        #expect(digest?.totalInMinor == 0)
        #expect(digest?.totalOutMinor == 0)
        #expect(digest?.topCategories.isEmpty == true)
        #expect(digest?.upcomingBills.isEmpty == true)
    }

    @Test("In/out totals: non-hidden, non-internal-transfer, week-scoped")
    func inOutTotals() {
        let digest = DigestBuilder.build(
            weekKey: week,
            transactions: [
                txn(id: "a", amountMinor: 5000, date: "2026-08-25"),
                txn(id: "b", amountMinor: 4000, date: "2026-08-28", categoryId: "dining"),
                // Paycheck: excluded from budget but IS household money in.
                txn(id: "pay", amountMinor: 200000, direction: .income, date: "2026-08-28",
                    categoryId: "income", pfcPrimary: "INCOME", excludeFromBudget: true),
                // Internal transfer: excluded from in/out entirely.
                txn(id: "xfer", amountMinor: 50000, date: "2026-08-27",
                    categoryId: nil, pfcPrimary: "TRANSFER_OUT", excludeFromBudget: true),
                // Hidden: excluded from everything.
                txn(id: "hid", amountMinor: 9999, date: "2026-08-25", isHidden: true),
                // Outside the week: excluded.
                txn(id: "old", amountMinor: 7777, date: "2026-08-23"),
            ],
            allocations: [:],
            recurringItems: []
        )
        #expect(digest?.totalInMinor == 200000)
        #expect(digest?.totalOutMinor == 9000)
    }

    @Test("Top categories: ranked by week spend, capped, refunds netted, positives only")
    func topCategories() {
        let digest = DigestBuilder.build(
            weekKey: week,
            transactions: [
                txn(id: "a", amountMinor: 5000, date: "2026-08-25", attributedTo: .member("uid-a")),
                txn(id: "b", amountMinor: 3000, date: "2026-08-26"),
                txn(id: "r", amountMinor: 1000, direction: .income, date: "2026-08-27",
                    attributedTo: .member("uid-b")),                                   // refund
                txn(id: "c", amountMinor: 4000, date: "2026-08-28", categoryId: "dining",
                    attributedTo: .member("uid-b")),
                txn(id: "d", amountMinor: 2000, date: "2026-08-28", categoryId: "gas"),
                txn(id: "e", amountMinor: 1500, date: "2026-08-28", categoryId: "fun"),
                // A category netting negative never ranks.
                txn(id: "neg", amountMinor: 2500, direction: .income, date: "2026-08-26",
                    categoryId: "returns"),
            ],
            allocations: [:],
            recurringItems: []
        )
        let ids = digest?.topCategories.map(\.categoryId)
        #expect(ids == ["groceries", "dining", "gas"])   // top 3 of 4 positives
        #expect(digest?.topCategories.first?.weekSpentMinor == 7000)  // 5000+3000−1000

        // Per-partner figures appear only inside category context: A / B / Joint.
        let groceries = digest?.topCategories.first
        #expect(groceries?.spentByAttribution["uid-a"] == 5000)
        #expect(groceries?.spentByAttribution["uid-b"] == -1000)
        #expect(groceries?.spentByAttribution["joint"] == 3000)
    }

    @Test("Pace and month-to-date context come from the month of the week's Sunday")
    func paceContext() {
        let digest = DigestBuilder.build(
            weekKey: week,
            transactions: [
                txn(id: "a", amountMinor: 7000, date: "2026-08-25"),
                // Earlier in August, outside the week: counts toward month-to-date.
                txn(id: "b", amountMinor: 2000, date: "2026-08-10"),
                // September spend never leaks into August's context.
                txn(id: "c", amountMinor: 4000, date: "2026-09-01"),
            ],
            allocations: ["groceries": 31000],
            recurringItems: []
        )
        let groceries = digest?.topCategories.first
        #expect(groceries?.weekSpentMinor == 7000)
        #expect(groceries?.monthSpentMinor == 9000)
        #expect(groceries?.allocatedMinor == 31000)
        // Sunday 2026-08-30 is day 30 of 31: pace = round(31000 × 30/31) = 30000.
        #expect(groceries?.paceMinor == 30000)
    }

    @Test("Unbudgeted categories carry nil allocation and nil pace")
    func unbudgetedCategory() {
        let digest = DigestBuilder.build(
            weekKey: week,
            transactions: [txn(id: "a", amountMinor: 1000, date: "2026-08-25")],
            allocations: ["dining": 5000],
            recurringItems: []
        )
        let groceries = digest?.topCategories.first
        #expect(groceries?.allocatedMinor == nil)
        #expect(groceries?.paceMinor == nil)
    }

    @Test("Split transactions contribute per-split categories and attributions")
    func splits() {
        let costco = txn(
            id: "a", amountMinor: 10000, date: "2026-08-26", categoryId: "shopping",
            splits: [
                .init(id: "s1", amountMinor: 7000, categoryId: "groceries", attributedTo: .member("uid-a")),
                .init(id: "s2", amountMinor: 3000, categoryId: "home", attributedTo: .joint),
            ]
        )
        let digest = DigestBuilder.build(
            weekKey: week, transactions: [costco], allocations: [:], recurringItems: [])
        let ids = digest?.topCategories.map(\.categoryId)
        #expect(ids == ["groceries", "home"])
        #expect(digest?.topCategories.first?.spentByAttribution == ["uid-a": 7000])
        #expect(digest?.topCategories.last?.spentByAttribution == ["joint": 3000])
    }

    @Test("Upcoming bills: the 7 days after the covered week, paused excluded, sorted")
    func upcomingBills() {
        func bill(_ id: String, merchant: String, due: String,
                  frequency: RecurringItem.Frequency = .monthly,
                  isPaused: Bool = false) -> RecurringItem {
            RecurringItem(
                id: id, merchant: merchant, amountMinor: 1599, frequency: frequency,
                nextDueDate: due, attributedTo: .member("uid-a"),
                accountId: "acct-1", isPaused: isPaused)
        }
        let digest = DigestBuilder.build(
            weekKey: week,
            transactions: [],
            allocations: [:],
            recurringItems: [
                bill("r1", merchant: "Netflix", due: "2026-09-02"),
                bill("r2", merchant: "Gym", due: "2026-08-31"),
                bill("r3", merchant: "Insurance", due: "2026-09-07"),        // outside window
                bill("r4", merchant: "Paused", due: "2026-09-01", isPaused: true),
                bill("r5", merchant: "Water", due: "2026-08-29"),            // already due in-week
            ]
        )
        // Window is 2026-08-31 … 2026-09-06.
        #expect(digest?.upcomingBills.map(\.merchant) == ["Gym", "Netflix"])
        #expect(digest?.upcomingBills.first?.dueDate == "2026-08-31")
    }

    @Test("Custom top-category count is honored")
    func topCategoryCount() {
        let digest = DigestBuilder.build(
            weekKey: week,
            transactions: [
                txn(id: "a", amountMinor: 3000, date: "2026-08-25", categoryId: "a"),
                txn(id: "b", amountMinor: 2000, date: "2026-08-25", categoryId: "b"),
                txn(id: "c", amountMinor: 1000, date: "2026-08-25", categoryId: "c"),
            ],
            allocations: [:],
            recurringItems: [],
            topCategoryCount: 2
        )
        #expect(digest?.topCategories.count == 2)
    }

    @Test("Digest is deterministic and Codable — the materialized doc round-trips")
    func codableRoundTrip() throws {
        let transactions = [
            txn(id: "a", amountMinor: 5000, date: "2026-08-25", attributedTo: .member("uid-a")),
            txn(id: "b", amountMinor: 4000, date: "2026-08-28", categoryId: "dining"),
        ]
        let first = DigestBuilder.build(
            weekKey: week, transactions: transactions, allocations: ["groceries": 31000],
            recurringItems: [])
        let second = DigestBuilder.build(
            weekKey: week, transactions: transactions.reversed(), allocations: ["groceries": 31000],
            recurringItems: [])
        #expect(first == second)   // input order never changes the digest

        let digest = try #require(first)
        let data = try JSONEncoder().encode(digest)
        let decoded = try JSONDecoder().decode(WeeklyDigest.self, from: data)
        #expect(decoded == digest)
    }
}
