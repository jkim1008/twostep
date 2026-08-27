import Foundation

/// The materialized Weekly Sync digest (PRD §4.7.1): every number both
/// partners see, computed from plain inputs by pure template logic — zero ML,
/// zero clock access. The Cloud Function and the client-fallback path both
/// call this, so "identical picture" is a property of the function.
public struct WeeklyDigest: Hashable, Codable, Sendable {
    public let weekKey: String
    /// Monday, `"YYYY-MM-DD"`.
    public let startDate: String
    /// Sunday, `"YYYY-MM-DD"`.
    public let endDate: String
    /// Week income total (minor units) over non-hidden, non-internal-transfer
    /// transactions — the same formula as the Dashboard net (PRD §4.8).
    public let totalInMinor: Int
    /// Week expense total under the same filter.
    public let totalOutMinor: Int
    /// Top spending categories for the week (at most `topCategoryCount`),
    /// ranked by week spend descending.
    public let topCategories: [CategoryDigest]
    /// Bills due in the window after the covered week.
    public let upcomingBills: [UpcomingBill]

    public init(
        weekKey: String,
        startDate: String,
        endDate: String,
        totalInMinor: Int,
        totalOutMinor: Int,
        topCategories: [CategoryDigest],
        upcomingBills: [UpcomingBill]
    ) {
        self.weekKey = weekKey
        self.startDate = startDate
        self.endDate = endDate
        self.totalInMinor = totalInMinor
        self.totalOutMinor = totalOutMinor
        self.topCategories = topCategories
        self.upcomingBills = upcomingBills
    }
}

/// One category row in the digest.
///
/// Per-partner figures live only here — inside category context, always
/// alongside the Joint share, never as two ranked headline totals (PRD §4.7.1;
/// the §2.2 no-scoreboard rule is enforced by this shape).
public struct CategoryDigest: Hashable, Codable, Sendable {
    public let categoryId: String
    /// Net spend within the covered week (minor units, true value).
    public let weekSpentMinor: Int
    /// Month-to-date net spend through the week's Sunday, for the pace
    /// comparison (true value; display floors at 0).
    public let monthSpentMinor: Int
    /// Allocation for the month containing the week's Sunday; nil = unbudgeted.
    public let allocatedMinor: Int?
    /// Budget pace as of the week's Sunday; nil when unbudgeted.
    public let paceMinor: Int?
    /// Week net spend keyed by `Attribution.rawValue` — each partner's uid and
    /// `"joint"` as three separate figures. Joint is never split.
    public let spentByAttribution: [String: Int]

    public init(
        categoryId: String,
        weekSpentMinor: Int,
        monthSpentMinor: Int,
        allocatedMinor: Int?,
        paceMinor: Int?,
        spentByAttribution: [String: Int]
    ) {
        self.categoryId = categoryId
        self.weekSpentMinor = weekSpentMinor
        self.monthSpentMinor = monthSpentMinor
        self.allocatedMinor = allocatedMinor
        self.paceMinor = paceMinor
        self.spentByAttribution = spentByAttribution
    }
}

/// One expected bill in the digest's forward window.
public struct UpcomingBill: Hashable, Codable, Sendable {
    public let recurringItemId: String
    public let merchant: String
    public let amountMinor: Int
    public let dueDate: String
    public let attributedTo: Attribution
    public let accountId: String?

    public init(
        recurringItemId: String,
        merchant: String,
        amountMinor: Int,
        dueDate: String,
        attributedTo: Attribution,
        accountId: String?
    ) {
        self.recurringItemId = recurringItemId
        self.merchant = merchant
        self.amountMinor = amountMinor
        self.dueDate = dueDate
        self.attributedTo = attributedTo
        self.accountId = accountId
    }
}

/// Builds the Weekly Sync digest from plain inputs.
public enum DigestBuilder {
    /// - Parameters:
    ///   - weekKey: the completed Monday–Sunday week to cover.
    ///   - transactions: any superset of the relevant transactions; the
    ///     builder filters by date itself.
    ///   - allocations: budget allocations for the month containing the
    ///     week's Sunday (categoryId → minor units).
    ///   - recurringItems: all household recurring items; paused/expired ones
    ///     are excluded by the engine.
    ///   - topCategoryCount: max category rows (default 3, PRD §4.7.1).
    ///   - upcomingWindowDays: bill lookahead after the week ends (default 7).
    /// - Returns: nil only for a malformed `weekKey`.
    public static func build(
        weekKey: String,
        transactions: [Transaction],
        allocations: [String: Int],
        recurringItems: [RecurringItem],
        topCategoryCount: Int = 3,
        upcomingWindowDays: Int = 7
    ) -> WeeklyDigest? {
        guard let startDate = WeekKey.startDateString(of: weekKey),
              let endDate = WeekKey.endDateString(of: weekKey),
              let endDay = CalendarDay(dateString: endDate)
        else { return nil }

        let weekTransactions = transactions.filter {
            WeekKey.week(weekKey, containsDateString: $0.date)
        }

        // In/out totals: non-hidden, non-internal-transfer — the Dashboard
        // net formula, over the week.
        var totalIn = 0
        var totalOut = 0
        for transaction in weekTransactions
        where !transaction.isHidden && !PFCMapper.isInternalTransfer(primary: transaction.pfcPrimary) {
            switch transaction.direction {
            case .income: totalIn += transaction.amountMinor
            case .expense: totalOut += transaction.amountMinor
            }
        }

        // Category rows: budget-eligible week spend, split-aware, with
        // A / B / Joint drill-down figures.
        var weekSpent: [String: Int] = [:]
        var byAttribution: [String: [String: Int]] = [:]
        for transaction in weekTransactions
        where !transaction.excludeFromBudget && !transaction.isHidden {
            let net = transaction.direction == .expense ? 1 : -1
            if transaction.splits.isEmpty {
                let category = transaction.categoryId ?? BudgetMath.uncategorizedCategoryId
                weekSpent[category, default: 0] += net * transaction.amountMinor
                byAttribution[category, default: [:]][transaction.attributedTo.rawValue, default: 0]
                    += net * transaction.amountMinor
            } else {
                for split in transaction.splits {
                    let category = split.categoryId ?? BudgetMath.uncategorizedCategoryId
                    weekSpent[category, default: 0] += net * split.amountMinor
                    byAttribution[category, default: [:]][split.attributedTo.rawValue, default: 0]
                        += net * split.amountMinor
                }
            }
        }

        // Pace context: the month containing the week's Sunday.
        let month = String(format: "%04d-%02d", endDay.year, endDay.month)
        let daysInMonth = MonthKey.daysIn(month: endDay.month, year: endDay.year)
        let monthToDateTransactions = transactions.filter {
            guard let day = CalendarDay(dateString: $0.date) else { return false }
            return day <= endDay
        }
        let monthSpent = BudgetMath.spentPerCategory(
            transactions: monthToDateTransactions,
            month: month
        )

        let topCategories = weekSpent
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .prefix(max(0, topCategoryCount))
            .map { categoryId, spent in
                let allocation = allocations[categoryId]
                return CategoryDigest(
                    categoryId: categoryId,
                    weekSpentMinor: spent,
                    monthSpentMinor: monthSpent[categoryId] ?? 0,
                    allocatedMinor: allocation,
                    paceMinor: allocation.map {
                        BudgetMath.pace(
                            allocationMinor: $0,
                            daysElapsed: endDay.day,
                            daysInMonth: daysInMonth
                        )
                    },
                    spentByAttribution: byAttribution[categoryId] ?? [:]
                )
            }

        // Upcoming bills: occurrences in the window right after the week.
        let windowStart = endDay.adding(days: 1).dateString
        let windowEnd = endDay.adding(days: max(0, upcomingWindowDays)).dateString
        var upcomingBills: [UpcomingBill] = []
        for item in recurringItems {
            let dueDates = RecurrenceEngine.occurrences(
                of: item,
                fromDate: windowStart,
                toDate: windowEnd
            )
            for dueDate in dueDates {
                upcomingBills.append(UpcomingBill(
                    recurringItemId: item.id,
                    merchant: item.merchant,
                    amountMinor: item.amountMinor,
                    dueDate: dueDate,
                    attributedTo: item.attributedTo,
                    accountId: item.accountId
                ))
            }
        }
        upcomingBills.sort { lhs, rhs in
            lhs.dueDate != rhs.dueDate
                ? lhs.dueDate < rhs.dueDate
                : lhs.merchant < rhs.merchant
        }

        return WeeklyDigest(
            weekKey: weekKey,
            startDate: startDate,
            endDate: endDate,
            totalInMinor: totalIn,
            totalOutMinor: totalOut,
            topCategories: topCategories,
            upcomingBills: upcomingBills
        )
    }
}
