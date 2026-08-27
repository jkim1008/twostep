import Foundation
import TwoStepCore

/// Factory for the fictional demo household "Maya & Sam".
///
/// Every value here is invented for demonstration — no real people, accounts,
/// or spending. The seed is deterministic: both the demo month and every
/// date string are pinned so screens render identically on any device or CI
/// run. Amounts are integer minor units (cents) throughout.
enum DemoSeed {
    // MARK: Identity

    static let mayaUid = "demo-maya"
    static let samUid = "demo-sam"
    /// Neutral slate for the Joint badge (DESIGN.md §2.5) — joint spending
    /// belongs to no one.
    static let jointBadgeColorHex = "#64748B"

    /// The month every demo surface treats as "this month".
    static let focusMonth = "2026-08"
    /// The day the demo treats as "today" (inside `focusMonth`).
    static let focusDate = "2026-08-27"

    // MARK: Accounts (ids referenced by transactions)

    static let cashAccountId = "acct-cash"
    static let mayaCheckingId = "acct-maya-checking"
    static let samCardId = "acct-sam-card"
    static let jointCheckingId = "acct-joint-checking"

    // MARK: Household

    static func makeHousehold() -> Household {
        Household(
            id: "demo-household",
            name: "Maya & Sam",
            memberUids: [mayaUid, samUid],
            ownerUid: mayaUid
        )
    }

    static func makeMembers() -> [HouseholdMember] {
        [
            HouseholdMember(id: mayaUid, role: .owner, displayName: "Maya", colorHex: "#6366F1"),
            HouseholdMember(id: samUid, role: .partner, displayName: "Sam", colorHex: "#F97316")
        ]
    }

    // MARK: Categories (mirror the Cloud Function seed, functions/src/defaultCategories.ts)

    static func makeCategories() -> [TransactionCategory] {
        [
            category("housing", "Housing", "🏠", "#1E40AF", ["RENT_AND_UTILITIES"]),
            category("groceries", "Groceries", "🛒", "#F97316", ["FOOD_AND_DRINK.FOOD_AND_DRINK_GROCERIES"]),
            category("dining", "Dining", "🍽️", "#B45309", ["FOOD_AND_DRINK"]),
            category("transport", "Transport", "🚗", "#6366F1", ["TRANSPORTATION", "TRAVEL"]),
            category("entertainment", "Entertainment", "🎬", "#EC4899", ["ENTERTAINMENT"]),
            category("shopping", "Shopping", "🛍️", "#D97706", ["GENERAL_MERCHANDISE"]),
            category("health", "Health", "💊", "#6F8360", ["MEDICAL", "PERSONAL_CARE"]),
            category("subscriptions", "Subscriptions", "📱", "#8B5CF6", ["ENTERTAINMENT.ENTERTAINMENT_TV_AND_MOVIES"]),
            category("income", "Income", "💵", "#4F9D69", ["INCOME"]),
            category("transfers", "Transfers", "🔁", "#64748B", ["TRANSFER_IN", "TRANSFER_OUT", "LOAN_PAYMENTS"]),
            category("other", "Other", "✨", "#98A091", [])
        ]
    }

    /// Income & Transfers never move spending indicators (PRD §4.3, §4.4):
    /// their transactions default to `excludeFromBudget`.
    static let excludedCategoryIds: Set<String> = ["income", "transfers"]

    // MARK: Budget months (allocations for SIX categories only — budgeting is
    // opt-in per category; shopping, health, and other track spend unallocated)

    static func makeBudgetMonths() -> [BudgetMonth] {
        let july = BudgetMonth(
            month: "2026-07",
            allocations: [
                "housing": 2_200_00,
                "groceries": 620_00,
                "dining": 320_00,
                "transport": 260_00,
                "entertainment": 140_00,
                "subscriptions": 90_00
            ]
        )
        var august = july.copiedForward(to: focusMonth)
        august.allocations["groceries"] = 650_00
        august.allocations["dining"] = 350_00
        return [july, august]
    }

    // MARK: Assembly

    @MainActor
    static func makeRepositories() -> AppRepositories {
        AppRepositories(
            households: InMemoryHouseholdRepository(
                household: makeHousehold(),
                members: makeMembers(),
                currentMemberId: mayaUid
            ),
            transactions: InMemoryTransactionRepository(transactions: makeTransactions()),
            budgets: InMemoryBudgetRepository(
                categories: makeCategories(),
                excludedCategoryIds: excludedCategoryIds,
                budgetMonths: makeBudgetMonths()
            ),
            savings: makeSavingsRepository(),
            recurring: InMemoryRecurringRepository(items: makeRecurringItems()),
            events: makeEventRepository()
        )
    }

    // MARK: Helpers

    private static func category(
        _ id: String,
        _ name: String,
        _ emoji: String,
        _ colorHex: String,
        _ pfcMappings: [String]
    ) -> TransactionCategory {
        TransactionCategory(
            id: id,
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            isSystem: true,
            pfcMappings: pfcMappings
        )
    }

    /// Midday UTC on a demo calendar day — deterministic `Date` values for
    /// event timestamps without touching the device calendar or timezone.
    static func timestamp(_ dateString: String, hour: Int = 12) -> Date {
        let day = CalendarDay(dateString: dateString)
        let dayNumber = day?.dayNumber ?? 0
        return Date(timeIntervalSince1970: TimeInterval(dayNumber * 86_400 + hour * 3_600))
    }
}

/// The app's repository set, injected through the SwiftUI environment.
/// Demo builds hold the in-memory implementations; Firestore-backed
/// repositories swap in later behind the same protocols.
@MainActor
@Observable
final class AppRepositories {
    let households: any HouseholdRepository
    let transactions: any TransactionRepository
    let budgets: any BudgetRepository
    let savings: any SavingsRepository
    let recurring: any RecurringRepository
    let events: any EventRepository

    init(
        households: any HouseholdRepository,
        transactions: any TransactionRepository,
        budgets: any BudgetRepository,
        savings: any SavingsRepository,
        recurring: any RecurringRepository,
        events: any EventRepository
    ) {
        self.households = households
        self.transactions = transactions
        self.budgets = budgets
        self.savings = savings
        self.recurring = recurring
        self.events = events
    }
}
