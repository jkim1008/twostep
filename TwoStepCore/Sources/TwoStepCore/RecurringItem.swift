import Foundation

/// A recurring bill or subscription powering the upcoming-bills forecast.
///
/// Invariants (PRD §4.6):
/// - Items on **linked accounts are predictive only** — the real transaction
///   arrives via sync and links back via `Transaction.recurringItemId`.
///   **`autoLog` may be true only for the Cash account** (rent paid by check);
///   auto-logging a linked account would double-count. This is a cross-entity
///   invariant enforced at the write path; `RecurrenceEngine.shouldAutoLog`
///   re-checks it defensively.
/// - `nextDueDate` is a canonical `"YYYY-MM-DD"` string; advancing it is the
///   job of `RecurrenceEngine` (month-end clamping and all).
/// - Paused items neither auto-log nor forecast; end-dated items expire
///   silently once `nextDueDate` passes `endDate`.
public struct RecurringItem: Hashable, Codable, Sendable, Identifiable {
    public enum Frequency: String, Codable, Sendable, CaseIterable {
        case weekly
        case biweekly
        case monthly
        case yearly
    }

    public let id: String
    public var merchant: String
    public var amountMinor: Int
    public var frequency: Frequency
    /// `"YYYY-MM-DD"` — the next date this item is expected to charge.
    public var nextDueDate: String
    public var categoryId: String?
    public var attributedTo: Attribution
    public var accountId: String?
    /// Cash-only: create the transaction automatically on each due date.
    public var autoLog: Bool
    public var isPaused: Bool
    /// `"YYYY-MM-DD"` — last date the item may occur; nil = indefinite.
    public var endDate: String?

    public init(
        id: String,
        merchant: String,
        amountMinor: Int,
        frequency: Frequency,
        nextDueDate: String,
        categoryId: String? = nil,
        attributedTo: Attribution,
        accountId: String? = nil,
        autoLog: Bool = false,
        isPaused: Bool = false,
        endDate: String? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amountMinor = amountMinor
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.categoryId = categoryId
        self.attributedTo = attributedTo
        self.accountId = accountId
        self.autoLog = autoLog
        self.isPaused = isPaused
        self.endDate = endDate
    }
}
