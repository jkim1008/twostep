import Foundation

/// A shared savings goal — a scoreboard the couple moves forward together,
/// not a bank-backed planner (PRD §4.5).
///
/// Invariants:
/// - `savedAmountMinor` is an aggregate maintained by atomic increments in the
///   same batch as each `Contribution` write; it must always equal the sum of
///   the contribution history.
/// - The target can be **manual** (`manualTargetAmountMinor`) or **derived**
///   from the recurring plan (`recurringContributionMinor` × occurrences over
///   `durationMonths`). `targetAmountMinor` resolves manual first, then
///   derived, then nil (open-ended project).
/// - Derived weekly occurrences use round(durationMonths × 52 / 12) — a fixed,
///   deterministic rule so both devices derive the same target.
/// - Archived projects keep their history.
public struct SavingsProject: Hashable, Codable, Sendable, Identifiable {
    public enum Cadence: String, Codable, Sendable {
        case weekly
        case monthly
    }

    public let id: String
    public var name: String
    public var emoji: String
    /// Planned contribution per cadence period, minor units. 0 = no plan.
    public var recurringContributionMinor: Int
    public var cadence: Cadence
    /// Planned duration; nil = open-ended (no derived target).
    public var durationMonths: Int?
    /// Explicit target set by the couple; wins over the derived target.
    public var manualTargetAmountMinor: Int?
    /// Increment-maintained aggregate of all contributions.
    public var savedAmountMinor: Int
    public var isArchived: Bool

    public init(
        id: String,
        name: String,
        emoji: String,
        recurringContributionMinor: Int = 0,
        cadence: Cadence = .monthly,
        durationMonths: Int? = nil,
        manualTargetAmountMinor: Int? = nil,
        savedAmountMinor: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.recurringContributionMinor = recurringContributionMinor
        self.cadence = cadence
        self.durationMonths = durationMonths
        self.manualTargetAmountMinor = manualTargetAmountMinor
        self.savedAmountMinor = savedAmountMinor
        self.isArchived = isArchived
    }

    /// Target derived from the recurring plan, or nil when the plan is
    /// incomplete (no contribution amount or no duration).
    public var derivedTargetAmountMinor: Int? {
        guard recurringContributionMinor > 0, let durationMonths, durationMonths > 0 else {
            return nil
        }
        let occurrences: Int = switch cadence {
        case .monthly: durationMonths
        // round(months × 52/12), in integer math: (m × 52 + 6) / 12.
        case .weekly: (durationMonths * 52 + 6) / 12
        }
        return recurringContributionMinor * occurrences
    }

    /// Manual target if set, else the derived one, else nil (open-ended).
    public var targetAmountMinor: Int? {
        manualTargetAmountMinor ?? derivedTargetAmountMinor
    }

    /// Progress in [0, 1], nil when the project has no target. Overshoot caps
    /// at 1.
    public var progressFraction: Double? {
        guard let target = targetAmountMinor, target > 0 else { return nil }
        return min(1.0, Double(savedAmountMinor) / Double(target))
    }
}

/// One contribution to a savings project, attributed to the partner who made it.
///
/// Invariants (PRD §4.5):
/// - Writing/deleting a contribution adjusts the project's `savedAmountMinor`
///   by the same amount in the same atomic batch — safe under two concurrent
///   writers, no lost updates.
/// - `date` is a canonical `"YYYY-MM-DD"` string.
public struct Contribution: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let projectId: String
    public var amountMinor: Int
    public var date: String
    public var note: String?
    public let contributedByUid: String

    public init(
        id: String,
        projectId: String,
        amountMinor: Int,
        date: String,
        note: String? = nil,
        contributedByUid: String
    ) {
        self.id = id
        self.projectId = projectId
        self.amountMinor = amountMinor
        self.date = date
        self.note = note
        self.contributedByUid = contributedByUid
    }
}
