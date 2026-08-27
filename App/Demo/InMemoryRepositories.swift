import Foundation
import Observation
import TwoStepCore

// In-memory repository implementations seeded from `DemoSeed`. They hold the
// demo household's state for the whole session; every mutation goes through
// the same methods a Firestore-backed implementation would expose.

@MainActor
@Observable
final class InMemoryHouseholdRepository: HouseholdRepository {
    private(set) var household: Household
    private(set) var members: [HouseholdMember]
    private(set) var currentMember: HouseholdMember?

    init(household: Household, members: [HouseholdMember], currentMemberId: String?) {
        self.household = household
        self.members = members
        self.currentMember = members.first { $0.id == currentMemberId }
    }

    func signIn(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = members.first { $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }
        currentMember = match ?? members.first
    }

    func member(withId uid: String) -> HouseholdMember? {
        members.first { $0.id == uid }
    }

    func displayName(for attribution: Attribution) -> String {
        switch attribution {
        case .joint:
            return "Joint"
        case .member(let uid):
            return member(withId: uid)?.displayName ?? "Former partner"
        }
    }

    func badgeColorHex(for attribution: Attribution) -> String {
        switch attribution {
        case .joint:
            return DemoSeed.jointBadgeColorHex
        case .member(let uid):
            return member(withId: uid)?.colorHex ?? DemoSeed.jointBadgeColorHex
        }
    }
}

@MainActor
@Observable
final class InMemoryTransactionRepository: TransactionRepository {
    private(set) var transactions: [Transaction]

    init(transactions: [Transaction]) {
        self.transactions = Self.sorted(transactions)
    }

    func add(_ transaction: Transaction) {
        transactions = Self.sorted(transactions + [transaction])
    }

    func update(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index] = transaction
        transactions = Self.sorted(transactions)
    }

    func transaction(withId id: String) -> Transaction? {
        transactions.first { $0.id == id }
    }

    func transactions(inMonth month: String) -> [Transaction] {
        transactions.filter { MonthKey.key(forDateString: $0.date) == month }
    }

    /// Reverse-chronological, ties broken by id for a stable feed order.
    private static func sorted(_ transactions: [Transaction]) -> [Transaction] {
        transactions.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }
}

@MainActor
@Observable
final class InMemoryBudgetRepository: BudgetRepository {
    private(set) var categories: [TransactionCategory]
    private(set) var excludedCategoryIds: Set<String>
    private(set) var budgetMonths: [BudgetMonth]

    init(categories: [TransactionCategory], excludedCategoryIds: Set<String>, budgetMonths: [BudgetMonth]) {
        self.categories = categories
        self.excludedCategoryIds = excludedCategoryIds
        self.budgetMonths = budgetMonths.sorted { $0.month < $1.month }
    }

    func category(withId id: String) -> TransactionCategory? {
        categories.first { $0.id == id }
    }

    func budget(forMonth month: String) -> BudgetMonth? {
        budgetMonths.first { $0.month == month }
    }

    func setAllocation(_ amountMinor: Int?, forCategory categoryId: String, inMonth month: String) {
        var budget = budget(forMonth: month) ?? BudgetMonth(month: month)
        if let amountMinor {
            budget.allocations[categoryId] = max(0, amountMinor)
        } else {
            budget.allocations.removeValue(forKey: categoryId)
        }
        if let index = budgetMonths.firstIndex(where: { $0.month == month }) {
            budgetMonths[index] = budget
        } else {
            budgetMonths.append(budget)
            budgetMonths.sort { $0.month < $1.month }
        }
    }
}

@MainActor
@Observable
final class InMemorySavingsRepository: SavingsRepository {
    private(set) var projects: [SavingsProject]
    private(set) var contributions: [Contribution]

    init(projects: [SavingsProject], contributions: [Contribution]) {
        self.projects = projects
        self.contributions = contributions.sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }

    func project(withId id: String) -> SavingsProject? {
        projects.first { $0.id == id }
    }

    func contributions(forProject projectId: String) -> [Contribution] {
        contributions.filter { $0.projectId == projectId }
    }

    func add(_ project: SavingsProject) {
        projects.append(project)
    }

    func addContribution(_ contribution: Contribution) {
        guard let index = projects.firstIndex(where: { $0.id == contribution.projectId }) else { return }
        contributions.insert(contribution, at: 0)
        contributions.sort { ($0.date, $0.id) > ($1.date, $1.id) }
        projects[index].savedAmountMinor += contribution.amountMinor
    }

    func deleteContribution(withId id: String) {
        guard let contribution = contributions.first(where: { $0.id == id }),
              let index = projects.firstIndex(where: { $0.id == contribution.projectId })
        else { return }
        contributions.removeAll { $0.id == id }
        projects[index].savedAmountMinor -= contribution.amountMinor
    }
}

@MainActor
@Observable
final class InMemoryRecurringRepository: RecurringRepository {
    private(set) var items: [RecurringItem]

    init(items: [RecurringItem]) {
        self.items = items.sorted { $0.nextDueDate < $1.nextDueDate }
    }

    func item(withId id: String) -> RecurringItem? {
        items.first { $0.id == id }
    }

    func add(_ item: RecurringItem) {
        items.append(item)
        items.sort { $0.nextDueDate < $1.nextDueDate }
    }

    func update(_ item: RecurringItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        items.sort { $0.nextDueDate < $1.nextDueDate }
    }

    func upcomingItems(onOrAfter date: String) -> [RecurringItem] {
        items.filter { !$0.isPaused && $0.nextDueDate >= date }
    }
}

@MainActor
@Observable
final class InMemoryEventRepository: EventRepository {
    private(set) var events: [HouseholdEvent]
    /// Per-viewer read cursor (`alertsSeenAt` in the real schema, PRD §4.9).
    private var seenAt: Date

    var unreadCount: Int {
        events.count { $0.timestamp > seenAt }
    }

    init(events: [HouseholdEvent], seenAt: Date) {
        self.events = events.sorted { $0.timestamp > $1.timestamp }
        self.seenAt = seenAt
    }

    func append(_ event: HouseholdEvent) {
        events.insert(event, at: 0)
        events.sort { $0.timestamp > $1.timestamp }
    }

    func markAllSeen() {
        seenAt = Date()
    }
}
