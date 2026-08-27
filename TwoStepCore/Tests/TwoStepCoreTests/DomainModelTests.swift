import Foundation
import Testing
@testable import TwoStepCore

@Suite("Domain models — invariants and wire format")
struct DomainModelTests {
    // MARK: - Attribution

    @Test("Attribution encodes as a bare string: 'joint' or the uid")
    func attributionWireFormat() throws {
        let encoder = JSONEncoder()
        #expect(String(data: try encoder.encode(Attribution.joint), encoding: .utf8) == "\"joint\"")
        #expect(String(data: try encoder.encode(Attribution.member("uid-a")), encoding: .utf8) == "\"uid-a\"")

        let decoder = JSONDecoder()
        #expect(try decoder.decode(Attribution.self, from: Data("\"joint\"".utf8)) == .joint)
        #expect(try decoder.decode(Attribution.self, from: Data("\"uid-b\"".utf8)) == .member("uid-b"))
        #expect(Attribution(rawValue: "joint") == .joint)
        #expect(Attribution.member("uid-a").rawValue == "uid-a")
    }

    // MARK: - Transaction

    @Test("Transaction round-trips through Codable with every field set")
    func transactionRoundTrip() throws {
        let transaction = Transaction(
            id: "plaid-txn-1",
            source: .plaid,
            accountId: "acct-1",
            amountMinor: 8450,
            direction: .expense,
            date: "2026-08-25",
            postedDate: "2026-08-27",
            merchantName: "Blue Bottle",
            originalDescription: "BLUEBOTTLE 0042",
            categoryId: "coffee",
            categoryOverriddenByUser: true,
            pfcPrimary: "FOOD_AND_DRINK",
            pfcDetailed: "FOOD_AND_DRINK_COFFEE",
            pfcConfidence: "HIGH",
            attributedTo: .member("uid-a"),
            enteredByUid: "uid-a",
            status: .pending,
            pendingTransactionId: "pending-9",
            recurringItemId: "rec-1",
            excludeFromBudget: false,
            isHidden: true,
            hiddenByUid: "uid-b",
            notes: "team offsite",
            possibleDuplicateOf: "manual-3",
            mergedFromManualId: "manual-2",
            discussFlaggedByUid: "uid-b",
            discussNote: "was this work?",
            discussResolvedAt: Date(timeIntervalSince1970: 1_756_000_000),
            splits: [
                .init(id: "s1", amountMinor: 5000, categoryId: "coffee", attributedTo: .member("uid-a")),
                .init(id: "s2", amountMinor: 3450, categoryId: nil, attributedTo: .joint),
            ]
        )
        let data = try JSONEncoder().encode(transaction)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)
        #expect(decoded == transaction)
    }

    @Test("Signed amount and discussion state helpers")
    func transactionHelpers() {
        var transaction = Transaction(
            id: "t", source: .manual, amountMinor: 500, direction: .expense,
            date: "2026-08-25", attributedTo: .joint)
        #expect(transaction.signedAmountMinor == -500)
        transaction.direction = .income
        #expect(transaction.signedAmountMinor == 500)

        #expect(!transaction.isAwaitingDiscussion)
        transaction.discussFlaggedByUid = "uid-a"
        #expect(transaction.isAwaitingDiscussion)
        transaction.discussResolvedAt = Date(timeIntervalSince1970: 0)
        #expect(!transaction.isAwaitingDiscussion)
    }

    // MARK: - SavingsProject

    @Test("Derived target: monthly cadence multiplies straight through")
    func derivedTargetMonthly() {
        let project = SavingsProject(
            id: "p", name: "Japan trip", emoji: "🗾",
            recurringContributionMinor: 50000, cadence: .monthly, durationMonths: 12)
        #expect(project.derivedTargetAmountMinor == 600000)
        #expect(project.targetAmountMinor == 600000)
    }

    @Test("Derived target: weekly cadence uses round(months × 52 / 12) occurrences")
    func derivedTargetWeekly() {
        let year = SavingsProject(
            id: "p", name: "g", emoji: "🎯",
            recurringContributionMinor: 10000, cadence: .weekly, durationMonths: 12)
        #expect(year.derivedTargetAmountMinor == 520000)   // 52 weeks

        let halfYear = SavingsProject(
            id: "p", name: "g", emoji: "🎯",
            recurringContributionMinor: 10000, cadence: .weekly, durationMonths: 6)
        #expect(halfYear.derivedTargetAmountMinor == 260000)  // 26 weeks (26.5 rounds down)
    }

    @Test("Manual target wins over derived; no plan means no target")
    func targetResolution() {
        let manual = SavingsProject(
            id: "p", name: "g", emoji: "🎯",
            recurringContributionMinor: 50000, cadence: .monthly, durationMonths: 12,
            manualTargetAmountMinor: 999999)
        #expect(manual.targetAmountMinor == 999999)

        let openEnded = SavingsProject(id: "p", name: "g", emoji: "🎯")
        #expect(openEnded.derivedTargetAmountMinor == nil)
        #expect(openEnded.targetAmountMinor == nil)
        #expect(openEnded.progressFraction == nil)

        let noDuration = SavingsProject(
            id: "p", name: "g", emoji: "🎯",
            recurringContributionMinor: 50000, cadence: .monthly)
        #expect(noDuration.derivedTargetAmountMinor == nil)
    }

    @Test("Progress fraction caps at 1 and never divides by zero")
    func progressFraction() {
        var project = SavingsProject(
            id: "p", name: "g", emoji: "🎯",
            manualTargetAmountMinor: 100000, savedAmountMinor: 25000)
        #expect(project.progressFraction == 0.25)
        project.savedAmountMinor = 150000
        #expect(project.progressFraction == 1.0)
        project.manualTargetAmountMinor = 0
        #expect(project.progressFraction == nil)
    }

    // MARK: - BudgetMonth

    @Test("Copying a budget forward preserves allocations and records provenance")
    func budgetCopyForward() {
        let august = BudgetMonth(month: "2026-08", allocations: ["groceries": 31000])
        let september = august.copiedForward(to: "2026-09")
        #expect(september.month == "2026-09")
        #expect(september.allocations == august.allocations)
        #expect(september.copiedFromMonth == "2026-08")
        #expect(august.copiedFromMonth == nil)
    }

    // MARK: - LinkedAccount

    @Test("Default attribution: owned accounts → owner, nil owner → joint")
    func accountDefaultAttribution() {
        let hers = LinkedAccount(
            id: "a1", ownerUid: "uid-b", institutionName: "Chase", mask: "1234", type: .checking)
        let joint = LinkedAccount(
            id: "a2", institutionName: "Ally", mask: "9876", type: .savings)
        #expect(hers.defaultAttribution == .member("uid-b"))
        #expect(joint.defaultAttribution == .joint)
    }

    // MARK: - Wire spellings

    @Test("Enum raw values match the Firestore wire spellings")
    func wireSpellings() {
        #expect(HouseholdMember.Status.active.rawValue == "active")
        #expect(HouseholdMember.Status.left.rawValue == "left")
        #expect(Transaction.Source.plaid.rawValue == "plaid")
        #expect(Transaction.Status.pending.rawValue == "pending")
        #expect(Transaction.Direction.expense.rawValue == "expense")
        #expect(RecurringItem.Frequency.biweekly.rawValue == "biweekly")
        #expect(SavingsProject.Cadence.weekly.rawValue == "weekly")
        #expect(LinkedAccount.AccountType.cash.rawValue == "cash")
        #expect(HouseholdEvent.EventType.memberJoined.rawValue == "memberJoined")
        #expect(HouseholdEvent.EventType.contributionAdded.rawValue == "contributionAdded")
    }

    @Test("HouseholdEvent and Contribution round-trip through Codable")
    func eventAndContributionRoundTrip() throws {
        let event = HouseholdEvent(
            id: "e1", type: .accountLinked, actorUid: "uid-a",
            timestamp: Date(timeIntervalSince1970: 1_756_000_000),
            payload: "Linked Chase ••1234")
        let decodedEvent = try JSONDecoder().decode(
            HouseholdEvent.self, from: JSONEncoder().encode(event))
        #expect(decodedEvent == event)

        let contribution = Contribution(
            id: "c1", projectId: "p1", amountMinor: 20000, date: "2026-08-25",
            note: "bonus", contributedByUid: "uid-b")
        let decodedContribution = try JSONDecoder().decode(
            Contribution.self, from: JSONEncoder().encode(contribution))
        #expect(decodedContribution == contribution)
    }
}
