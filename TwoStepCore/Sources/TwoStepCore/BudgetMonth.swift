import Foundation

/// One month's budget: an allocations map keyed by category id, in minor units.
///
/// Invariants (PRD §4.4, §6.3):
/// - Doc id / `month` is a `MonthKey` string (`"YYYY-MM"`). One doc per month —
///   month history is free; editing this month never rewrites the past.
/// - Allocations are a map, not a subcollection: one read fetches the whole
///   month (a couple has < 50 categories).
/// - Spent totals are **computed, never stored here** — see `BudgetMath`.
/// - `copiedFromMonth` records provenance when a new month auto-copies the
///   previous month's allocations.
/// - Allocation values are non-negative integer minor units.
public struct BudgetMonth: Hashable, Codable, Sendable, Identifiable {
    /// `"YYYY-MM"` — also the Firestore doc id.
    public let month: String
    /// categoryId → allocated minor units.
    public var allocations: [String: Int]
    public var copiedFromMonth: String?

    public var id: String { month }

    public init(month: String, allocations: [String: Int] = [:], copiedFromMonth: String? = nil) {
        self.month = month
        self.allocations = allocations
        self.copiedFromMonth = copiedFromMonth
    }

    /// The next month's budget, auto-copied from this one with provenance.
    public func copiedForward(to month: String) -> BudgetMonth {
        BudgetMonth(month: month, allocations: allocations, copiedFromMonth: self.month)
    }
}
