import Foundation
import TwoStepCore

// Savings projects (with contributions from both partners), recurring items
// with next-due dates across the 30 days after the demo "today", and the
// household activity feed backing the Alert Center.

extension DemoSeed {
    // MARK: Savings

    @MainActor
    static func makeSavingsRepository() -> InMemorySavingsRepository {
        let contributions = makeContributions()
        let projects = makeProjects().map { project in
            var copy = project
            copy.savedAmountMinor = contributions
                .filter { $0.projectId == project.id }
                .reduce(0) { $0 + $1.amountMinor }
            return copy
        }
        return InMemorySavingsRepository(projects: projects, contributions: contributions)
    }

    /// Three shared projects: one duration-first ($200/mo × 8 months → derived
    /// $1,600 target), one manual-target, one larger fund.
    static func makeProjects() -> [SavingsProject] {
        [
            SavingsProject(
                id: "proj-anniversary-trip", name: "Anniversary Trip", emoji: "🏝️",
                recurringContributionMinor: 200_00, cadence: .monthly, durationMonths: 8
            ),
            SavingsProject(
                id: "proj-new-couch", name: "New Couch", emoji: "🛋️",
                manualTargetAmountMinor: 1_200_00
            ),
            SavingsProject(
                id: "proj-emergency-fund", name: "Emergency Fund", emoji: "🚨",
                manualTargetAmountMinor: 5_000_00
            )
        ]
    }

    static func makeContributions() -> [Contribution] {
        [
            give(1, "proj-anniversary-trip", 200_00, "2026-07-05", mayaUid, note: "Kickoff!"),
            give(2, "proj-anniversary-trip", 200_00, "2026-08-05", samUid),
            give(3, "proj-anniversary-trip", 50_00, "2026-08-20", mayaUid, note: "Leftover fun money"),
            give(4, "proj-new-couch", 150_00, "2026-07-12", samUid),
            give(5, "proj-new-couch", 100_00, "2026-07-26", mayaUid),
            give(6, "proj-new-couch", 150_00, "2026-08-16", samUid, note: "Sale ends Labor Day"),
            give(7, "proj-emergency-fund", 300_00, "2026-07-15", mayaUid),
            give(8, "proj-emergency-fund", 300_00, "2026-07-15", samUid),
            give(9, "proj-emergency-fund", 300_00, "2026-08-15", mayaUid),
            give(10, "proj-emergency-fund", 300_00, "2026-08-15", samUid)
        ]
    }

    // MARK: Recurring (next-due dates within 30 days of the demo "today")

    static func makeRecurringItems() -> [RecurringItem] {
        [
            RecurringItem(
                id: "rec-rent", merchant: "Maple Grove Apartments", amountMinor: 2_200_00,
                frequency: .monthly, nextDueDate: "2026-09-01", categoryId: "housing",
                attributedTo: .joint, accountId: cashAccountId, autoLog: true
            ),
            RecurringItem(
                id: "rec-netflix", merchant: "Netflix", amountMinor: 17_99,
                frequency: .monthly, nextDueDate: "2026-09-03", categoryId: "subscriptions",
                attributedTo: sam, accountId: samCardId
            ),
            RecurringItem(
                id: "rec-utilities", merchant: "City Power & Water", amountMinor: 140_00,
                frequency: .monthly, nextDueDate: "2026-09-08", categoryId: "housing",
                attributedTo: .joint, accountId: jointCheckingId
            ),
            RecurringItem(
                id: "rec-gym", merchant: "Peak Fitness", amountMinor: 45_00,
                frequency: .monthly, nextDueDate: "2026-09-14", categoryId: "health",
                attributedTo: maya, accountId: mayaCheckingId
            ),
            RecurringItem(
                id: "rec-car-insurance", merchant: "Geico Insurance", amountMinor: 128_00,
                frequency: .monthly, nextDueDate: "2026-09-21", categoryId: "transport",
                attributedTo: sam, accountId: samCardId
            )
        ]
    }

    // MARK: Events (household activity feed → Alert Center)

    @MainActor
    static func makeEventRepository() -> InMemoryEventRepository {
        // The viewer's read cursor sits mid-feed so the bell shows a real
        // unread badge on first launch.
        InMemoryEventRepository(events: makeEvents(), seenAt: timestamp("2026-08-20"))
    }

    static func makeEvents() -> [HouseholdEvent] {
        [
            event(1, .memberJoined, samUid, "2026-07-01", "Sam joined the household"),
            event(2, .accountLinked, mayaUid, "2026-07-01", "Maya linked Meridian Bank ••4821"),
            event(3, .accountLinked, samUid, "2026-07-02", "Sam linked Cascade Credit Union ••7310"),
            event(4, .projectCreated, mayaUid, "2026-07-04", "Maya created 🏝️ Anniversary Trip"),
            event(5, .contributionAdded, mayaUid, "2026-07-05", "Maya contributed $200 to 🏝️ Anniversary Trip"),
            event(6, .budgetChanged, mayaUid, "2026-07-06", "Maya set the July budget"),
            event(7, .projectCreated, samUid, "2026-07-10", "Sam created 🛋️ New Couch"),
            event(8, .contributionAdded, samUid, "2026-07-12", "Sam contributed $150 to 🛋️ New Couch"),
            event(9, .expenseAdded, mayaUid, "2026-07-31", "Maya added an expense — $34.00 · 🛒 Groceries"),
            event(10, .budgetChanged, samUid, "2026-08-01", "Sam updated August allocations"),
            event(11, .contributionAdded, samUid, "2026-08-05", "Sam contributed $200 to 🏝️ Anniversary Trip"),
            event(12, .expenseAdded, samUid, "2026-08-22", "Sam added an expense — $18.00 · 🍽️ Dining"),
            event(13, .contributionAdded, samUid, "2026-08-16", "Sam contributed $150 to 🛋️ New Couch"),
            event(14, .expenseAdded, mayaUid, "2026-08-27", "Maya added an expense — $9.40 · 🍽️ Dining")
        ]
    }

    // MARK: Helpers

    private static func give(
        _ number: Int, _ projectId: String, _ cents: Int,
        _ date: String, _ uid: String, note: String? = nil
    ) -> Contribution {
        Contribution(
            id: String(format: "demo-contrib-%02d", number),
            projectId: projectId, amountMinor: cents, date: date,
            note: note, contributedByUid: uid
        )
    }

    private static func event(
        _ number: Int, _ type: HouseholdEvent.EventType,
        _ actorUid: String, _ date: String, _ payload: String
    ) -> HouseholdEvent {
        HouseholdEvent(
            id: String(format: "demo-event-%02d", number),
            type: type, actorUid: actorUid,
            timestamp: timestamp(date), payload: payload
        )
    }
}
