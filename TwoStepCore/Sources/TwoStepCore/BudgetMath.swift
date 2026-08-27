import Foundation

/// Pure budget math (PRD §4.4). Spent totals are always computed from the
/// transaction list — never denormalized — so there are no counters to drift.
///
/// Eligibility rules, applied identically everywhere:
/// - Counted: `pending` **and** `posted` transactions (posted overwrites
///   correct any pending drift).
/// - Never counted: `excludeFromBudget == true` (income, internal transfers,
///   user-excluded) or `isHidden == true`.
/// - A transaction with splits contributes through its splits' categories and
///   amounts, not its own.
/// - Month membership is decided solely by `MonthKey.key(forDateString:)` over
///   the canonical `date` field.
///
/// Formula: spent(category, month) = Σ(expense-direction) − Σ(income-direction)
/// — refunds recategorized into a spending category net naturally. True values
/// may go negative; displays floor at 0 via `displaySpent`.
public enum BudgetMath {
    /// Bucket for eligible spending on transactions with no category.
    public static let uncategorizedCategoryId = "uncategorized"

    /// Net spent per category for one month, in minor units. Values can be
    /// negative (refund-heavy category) — that truth is preserved; floor only
    /// at display time.
    public static func spentPerCategory(
        transactions: [Transaction],
        month: String
    ) -> [String: Int] {
        var spent: [String: Int] = [:]
        for transaction in transactions where isBudgetEligible(transaction, month: month) {
            if transaction.splits.isEmpty {
                let key = transaction.categoryId ?? uncategorizedCategoryId
                spent[key, default: 0] += netContribution(
                    amountMinor: transaction.amountMinor,
                    direction: transaction.direction
                )
            } else {
                for split in transaction.splits {
                    let key = split.categoryId ?? uncategorizedCategoryId
                    spent[key, default: 0] += netContribution(
                        amountMinor: split.amountMinor,
                        direction: transaction.direction
                    )
                }
            }
        }
        return spent
    }

    /// Total net spent across all categories for the month.
    public static func totalSpent(transactions: [Transaction], month: String) -> Int {
        spentPerCategory(transactions: transactions, month: month).values.reduce(0, +)
    }

    /// Display value: floored at 0. The true (possibly negative) value is
    /// what callers keep for math; this is only for rings and labels.
    public static func displaySpent(_ trueSpentMinor: Int) -> Int {
        max(0, trueSpentMinor)
    }

    /// Budget pace: allocation × (daysElapsed ÷ daysInMonth), rounded half up,
    /// in minor units. `daysElapsed` is clamped to `0...daysInMonth`.
    public static func pace(allocationMinor: Int, daysElapsed: Int, daysInMonth: Int) -> Int {
        guard daysInMonth > 0, allocationMinor > 0 else { return 0 }
        let clampedDays = min(max(daysElapsed, 0), daysInMonth)
        let numerator = allocationMinor * clampedDays
        return (numerator * 2 + daysInMonth) / (daysInMonth * 2)
    }

    /// Categories at risk: true spend strictly exceeds pace, or exceeds 90% of
    /// the allocation. Categories with no allocation are at risk as soon as
    /// they have positive spend.
    public static func atRiskCategoryIds(
        spent: [String: Int],
        allocations: [String: Int],
        daysElapsed: Int,
        daysInMonth: Int
    ) -> Set<String> {
        var atRisk: Set<String> = []
        for (categoryId, trueSpent) in spent {
            let allocation = allocations[categoryId] ?? 0
            if allocation <= 0 {
                if trueSpent > 0 { atRisk.insert(categoryId) }
                continue
            }
            let paceMinor = pace(
                allocationMinor: allocation,
                daysElapsed: daysElapsed,
                daysInMonth: daysInMonth
            )
            // spent > 90% of allocation, in integer math: spent × 10 > allocation × 9.
            if trueSpent > paceMinor || trueSpent * 10 > allocation * 9 {
                atRisk.insert(categoryId)
            }
        }
        return atRisk
    }

    /// The shared eligibility gate: non-excluded, non-hidden, dated in the
    /// month. Both `pending` and `posted` count.
    public static func isBudgetEligible(_ transaction: Transaction, month: String) -> Bool {
        !transaction.excludeFromBudget
            && !transaction.isHidden
            && MonthKey.key(forDateString: transaction.date) == month
    }

    // MARK: - Private

    private static func netContribution(amountMinor: Int, direction: Transaction.Direction) -> Int {
        direction == .expense ? amountMinor : -amountMinor
    }
}
