import Foundation
import Observation
import TwoStepCore

// Protocol-fronted data access (PRD §7.1). Screens depend only on these
// protocols; the in-memory demo implementations below them can be swapped
// for Firestore-backed repositories (snapshot listeners → AsyncStream)
// without touching a single view. All mutations flow through a repository
// so every surface stays consistent.

/// Household identity: the two members, the signed-in member, and
/// attribution resolution (name + badge color) for every surface.
@MainActor
protocol HouseholdRepository: AnyObject, Observable {
    var household: Household { get }
    var members: [HouseholdMember] { get }
    var currentMember: HouseholdMember? { get }

    func signIn(named name: String)
    func member(withId uid: String) -> HouseholdMember?
    /// Display name for an attribution: the member's snapshotted name, or "Joint".
    func displayName(for attribution: Attribution) -> String
    /// Badge color for an attribution: the member's color, or neutral slate for Joint.
    func badgeColorHex(for attribution: Attribution) -> String
}

/// The household's merged transaction feed (imports + manual entries).
@MainActor
protocol TransactionRepository: AnyObject, Observable {
    var transactions: [Transaction] { get }

    func add(_ transaction: Transaction)
    func update(_ transaction: Transaction)
    func transaction(withId id: String) -> Transaction?
    func transactions(inMonth month: String) -> [Transaction]
}

/// Categories and per-month budget allocations (PRD §4.4: budgeting is
/// opt-in per category; tracking is universal).
@MainActor
protocol BudgetRepository: AnyObject, Observable {
    var categories: [TransactionCategory] { get }
    /// Categories whose transactions default to `excludeFromBudget`
    /// (Income & Transfers) — they never move spending indicators.
    var excludedCategoryIds: Set<String> { get }
    var budgetMonths: [BudgetMonth] { get }

    func category(withId id: String) -> TransactionCategory?
    func budget(forMonth month: String) -> BudgetMonth?
    /// Sets (or clears, with nil) one category's allocation for one month.
    func setAllocation(_ amountMinor: Int?, forCategory categoryId: String, inMonth month: String)
}

/// Shared savings projects and their contribution ledgers (PRD §4.5).
@MainActor
protocol SavingsRepository: AnyObject, Observable {
    var projects: [SavingsProject] { get }
    var contributions: [Contribution] { get }

    func project(withId id: String) -> SavingsProject?
    func contributions(forProject projectId: String) -> [Contribution]
    func add(_ project: SavingsProject)
    /// Records a contribution and adjusts the project aggregate in the same
    /// mutation — mirroring the atomic-batch invariant of the real backend.
    func addContribution(_ contribution: Contribution)
    func deleteContribution(withId id: String)
}

/// Recurring bills powering the upcoming-payments calendar (PRD §4.6).
@MainActor
protocol RecurringRepository: AnyObject, Observable {
    var items: [RecurringItem] { get }

    func item(withId id: String) -> RecurringItem?
    func add(_ item: RecurringItem)
    func update(_ item: RecurringItem)
    /// Active (non-paused) items due on or after the given day, soonest first.
    func upcomingItems(onOrAfter date: String) -> [RecurringItem]
}

/// The household activity feed surfaced as the Alert Center (PRD §4.9).
@MainActor
protocol EventRepository: AnyObject, Observable {
    var events: [HouseholdEvent] { get }
    /// Rows newer than the viewer's read cursor.
    var unreadCount: Int { get }

    func append(_ event: HouseholdEvent)
    func markAllSeen()
}
