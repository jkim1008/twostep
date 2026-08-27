import Testing
@testable import TwoStepCore

@Suite("BudgetMath — spent, pace, at-risk")
struct BudgetMathTests {
    private func txn(
        id: String = "t1",
        amountMinor: Int,
        direction: Transaction.Direction = .expense,
        date: String = "2026-08-15",
        categoryId: String? = "groceries",
        status: Transaction.Status = .posted,
        excludeFromBudget: Bool = false,
        isHidden: Bool = false,
        splits: [Transaction.Split] = []
    ) -> Transaction {
        Transaction(
            id: id,
            source: .manual,
            accountId: "acct-1",
            amountMinor: amountMinor,
            direction: direction,
            date: date,
            categoryId: categoryId,
            attributedTo: .joint,
            status: status,
            excludeFromBudget: excludeFromBudget,
            isHidden: isHidden,
            splits: splits
        )
    }

    // MARK: - spentPerCategory

    @Test("Expenses sum per category; income in a category nets against it")
    func expenseIncomeNetting() {
        let spent = BudgetMath.spentPerCategory(
            transactions: [
                txn(id: "a", amountMinor: 5000),
                txn(id: "b", amountMinor: 3000),
                txn(id: "c", amountMinor: 1000, direction: .income),   // refund
                txn(id: "d", amountMinor: 4200, categoryId: "dining"),
            ],
            month: "2026-08"
        )
        #expect(spent["groceries"] == 7000)
        #expect(spent["dining"] == 4200)
    }

    @Test("Refund-heavy category goes negative in truth; display floors at 0")
    func negativeNettingAndDisplayFloor() {
        let spent = BudgetMath.spentPerCategory(
            transactions: [
                txn(id: "a", amountMinor: 1000),
                txn(id: "b", amountMinor: 6000, direction: .income),
            ],
            month: "2026-08"
        )
        #expect(spent["groceries"] == -5000)                  // true value preserved
        #expect(BudgetMath.displaySpent(-5000) == 0)          // display floor
        #expect(BudgetMath.displaySpent(7000) == 7000)
        #expect(BudgetMath.displaySpent(0) == 0)
    }

    @Test("Pending and posted both count")
    func pendingCounts() {
        let spent = BudgetMath.spentPerCategory(
            transactions: [
                txn(id: "a", amountMinor: 2000, status: .pending),
                txn(id: "b", amountMinor: 3000, status: .posted),
            ],
            month: "2026-08"
        )
        #expect(spent["groceries"] == 5000)
    }

    @Test("Excluded, hidden, and other-month transactions never count")
    func exclusions() {
        let spent = BudgetMath.spentPerCategory(
            transactions: [
                txn(id: "a", amountMinor: 1000),
                txn(id: "b", amountMinor: 2000, excludeFromBudget: true),
                txn(id: "c", amountMinor: 3000, isHidden: true),
                txn(id: "d", amountMinor: 4000, date: "2026-07-31"),
                txn(id: "e", amountMinor: 5000, date: "2026-09-01"),
                txn(id: "f", amountMinor: 6000, date: "not-a-date"),
            ],
            month: "2026-08"
        )
        #expect(spent == ["groceries": 1000])
    }

    @Test("Uncategorized eligible spend lands in the uncategorized bucket")
    func uncategorizedBucket() {
        let spent = BudgetMath.spentPerCategory(
            transactions: [txn(id: "a", amountMinor: 1500, categoryId: nil)],
            month: "2026-08"
        )
        #expect(spent[BudgetMath.uncategorizedCategoryId] == 1500)
    }

    @Test("A split transaction contributes through its children, not its own category")
    func splitsConsumed() {
        let costco = txn(
            id: "a",
            amountMinor: 10000,
            categoryId: "shopping",   // parent category must be ignored
            splits: [
                .init(id: "s1", amountMinor: 7000, categoryId: "groceries", attributedTo: .joint),
                .init(id: "s2", amountMinor: 2000, categoryId: "home", attributedTo: .member("uid-a")),
                .init(id: "s3", amountMinor: 1000, categoryId: nil, attributedTo: .joint),
            ]
        )
        let spent = BudgetMath.spentPerCategory(transactions: [costco], month: "2026-08")
        #expect(spent["groceries"] == 7000)
        #expect(spent["home"] == 2000)
        #expect(spent[BudgetMath.uncategorizedCategoryId] == 1000)
        #expect(spent["shopping"] == nil)
    }

    @Test("Hidden or excluded parent removes its splits too")
    func hiddenParentRemovesSplits() {
        let hidden = txn(
            id: "a",
            amountMinor: 5000,
            isHidden: true,
            splits: [.init(id: "s1", amountMinor: 5000, categoryId: "groceries", attributedTo: .joint)]
        )
        #expect(BudgetMath.spentPerCategory(transactions: [hidden], month: "2026-08").isEmpty)
    }

    @Test("Total spent sums all categories")
    func totalSpent() {
        let total = BudgetMath.totalSpent(
            transactions: [
                txn(id: "a", amountMinor: 5000),
                txn(id: "b", amountMinor: 4200, categoryId: "dining"),
                txn(id: "c", amountMinor: 1000, direction: .income),
            ],
            month: "2026-08"
        )
        #expect(total == 8200)
    }

    // MARK: - pace

    @Test("Pace is allocation × daysElapsed / daysInMonth, rounded half up")
    func paceFormula() {
        #expect(BudgetMath.pace(allocationMinor: 31000, daysElapsed: 15, daysInMonth: 31) == 15000)
        #expect(BudgetMath.pace(allocationMinor: 31000, daysElapsed: 31, daysInMonth: 31) == 31000)
        #expect(BudgetMath.pace(allocationMinor: 1000, daysElapsed: 1, daysInMonth: 3) == 333)   // 333.33 rounds down
        #expect(BudgetMath.pace(allocationMinor: 100, daysElapsed: 1, daysInMonth: 8) == 13)     // 12.5 rounds up
    }

    @Test("Pace clamps days and degenerate inputs to safe values")
    func paceBoundaries() {
        #expect(BudgetMath.pace(allocationMinor: 5000, daysElapsed: 40, daysInMonth: 31) == 5000)
        #expect(BudgetMath.pace(allocationMinor: 5000, daysElapsed: -2, daysInMonth: 31) == 0)
        #expect(BudgetMath.pace(allocationMinor: 5000, daysElapsed: 10, daysInMonth: 0) == 0)
        #expect(BudgetMath.pace(allocationMinor: 0, daysElapsed: 10, daysInMonth: 31) == 0)
    }

    // MARK: - atRisk

    @Test("At risk when spend exceeds pace")
    func atRiskOverPace() {
        // Pace at day 10 of 30 with 30000 allocated = 10000.
        let atRisk = BudgetMath.atRiskCategoryIds(
            spent: ["groceries": 10001, "dining": 10000, "gas": 9999],
            allocations: ["groceries": 30000, "dining": 30000, "gas": 30000],
            daysElapsed: 10,
            daysInMonth: 30
        )
        #expect(atRisk == ["groceries"])   // strictly over pace only
    }

    @Test("At risk when spend exceeds 90% of allocation even while under pace")
    func atRiskNinetyPercent() {
        // Day 30 of 31: pace = round(10000 × 30/31) = 9677.
        let atRisk = BudgetMath.atRiskCategoryIds(
            spent: ["groceries": 9200, "dining": 9000],
            allocations: ["groceries": 10000, "dining": 10000],
            daysElapsed: 30,
            daysInMonth: 31
        )
        #expect(atRisk.contains("groceries"))   // 92% > 90%, though under pace
        #expect(!atRisk.contains("dining"))     // exactly 90% is not over
    }

    @Test("Unallocated categories are at risk on any positive spend; refunds are not")
    func atRiskEdges() {
        let atRisk = BudgetMath.atRiskCategoryIds(
            spent: ["impulse": 1, "quiet": 0, "refunds": -500],
            allocations: [:],
            daysElapsed: 5,
            daysInMonth: 31
        )
        #expect(atRisk == ["impulse"])
    }
}
