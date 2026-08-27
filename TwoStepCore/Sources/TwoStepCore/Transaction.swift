import Foundation

/// The load-bearing entity of the whole product (PRD §6.3): one row in the
/// household's merged feed, whether imported via Plaid or entered manually.
///
/// Invariants:
/// - `amountMinor` is an unsigned integer count of minor units (cents);
///   sign lives exclusively in `direction`. Plaid's sign convention is
///   converted once at the ingest boundary, never here.
/// - `date` is the canonical calendar `"YYYY-MM-DD"` string set at ingest to
///   `authorized_date ?? posted date` (the user-perceived purchase date).
///   `MonthKey`/`WeekKey` consume only this field; the raw posted date is
///   kept separately in `postedDate`.
/// - Imported transactions (`source == .plaid`) are never hard-deleted by
///   users — `isHidden` is the symmetric, audited household archive.
/// - `splits`, when non-empty, carry their own category/attribution/amount and
///   must sum to `amountMinor`; budget and digest math then consume the splits
///   and ignore the parent's category/attribution. No splits UI ships in v1,
///   but the schema and math support them from day one.
/// - Hiding/excluding applies at the parent level only; a hidden or excluded
///   parent removes all of its splits from budget math.
public struct Transaction: Hashable, Codable, Sendable, Identifiable {
    public enum Source: String, Codable, Sendable {
        case plaid
        case manual
    }

    public enum Direction: String, Codable, Sendable {
        case expense
        case income
    }

    public enum Status: String, Codable, Sendable {
        case pending
        case posted
    }

    /// A child split of one transaction (one Costco run, three categories).
    /// Children sum to the parent's `amountMinor` and carry their own
    /// category and attribution.
    public struct Split: Hashable, Codable, Sendable, Identifiable {
        public let id: String
        public var amountMinor: Int
        public var categoryId: String?
        public var attributedTo: Attribution

        public init(id: String, amountMinor: Int, categoryId: String?, attributedTo: Attribution) {
            self.id = id
            self.amountMinor = amountMinor
            self.categoryId = categoryId
            self.attributedTo = attributedTo
        }
    }

    /// Doc id: the Plaid `transaction_id` for imports, a UUID for manual entries.
    public let id: String
    public let source: Source
    /// nil = the author didn't tag an account on a manual quick-add;
    /// imported transactions always carry one.
    public var accountId: String?
    /// Unsigned minor units; direction carries the sign.
    public var amountMinor: Int
    public var direction: Direction
    /// Canonical calendar date `"YYYY-MM-DD"` — the only field month/week
    /// bucketing reads.
    public var date: String
    /// Raw posted date from the institution, kept separately from `date`.
    public var postedDate: String?
    public var merchantName: String?
    public var originalDescription: String?
    public var categoryId: String?
    /// Guards re-sync from clobbering a user's recategorization.
    public var categoryOverriddenByUser: Bool
    /// Raw Plaid personal-finance-category triple, stored so mapping can be
    /// re-run retroactively.
    public var pfcPrimary: String?
    public var pfcDetailed: String?
    public var pfcConfidence: String?
    public var attributedTo: Attribution
    /// Audit: who created the record (manual entries), if known.
    public var enteredByUid: String?
    public var status: Status
    /// Plaid's pending-transaction id, linking a posted txn to the pending
    /// one it replaces.
    public var pendingTransactionId: String?
    /// Set when this transaction matched an active recurring item.
    public var recurringItemId: String?
    public var excludeFromBudget: Bool
    /// Symmetric household-level archive — both partners see the same hidden
    /// state; `hiddenByUid` records who hid it.
    public var isHidden: Bool
    public var hiddenByUid: String?
    public var notes: String?
    /// Medium-confidence dedup: id of the transaction this may duplicate.
    public var possibleDuplicateOf: String?
    /// Auto-merge audit: id of the manual doc whose user fields were copied
    /// onto this imported doc.
    public var mergedFromManualId: String?
    /// "Let's discuss" flag (PRD §4.7.2): flagged-by, optional note, and a
    /// resolution timestamp once either partner resolves it.
    public var discussFlaggedByUid: String?
    public var discussNote: String?
    public var discussResolvedAt: Date?
    /// Child splits; empty for the common case. See type-level invariants.
    public var splits: [Split]

    public init(
        id: String,
        source: Source,
        accountId: String? = nil,
        amountMinor: Int,
        direction: Direction,
        date: String,
        postedDate: String? = nil,
        merchantName: String? = nil,
        originalDescription: String? = nil,
        categoryId: String? = nil,
        categoryOverriddenByUser: Bool = false,
        pfcPrimary: String? = nil,
        pfcDetailed: String? = nil,
        pfcConfidence: String? = nil,
        attributedTo: Attribution,
        enteredByUid: String? = nil,
        status: Status = .posted,
        pendingTransactionId: String? = nil,
        recurringItemId: String? = nil,
        excludeFromBudget: Bool = false,
        isHidden: Bool = false,
        hiddenByUid: String? = nil,
        notes: String? = nil,
        possibleDuplicateOf: String? = nil,
        mergedFromManualId: String? = nil,
        discussFlaggedByUid: String? = nil,
        discussNote: String? = nil,
        discussResolvedAt: Date? = nil,
        splits: [Split] = []
    ) {
        self.id = id
        self.source = source
        self.accountId = accountId
        self.amountMinor = amountMinor
        self.direction = direction
        self.date = date
        self.postedDate = postedDate
        self.merchantName = merchantName
        self.originalDescription = originalDescription
        self.categoryId = categoryId
        self.categoryOverriddenByUser = categoryOverriddenByUser
        self.pfcPrimary = pfcPrimary
        self.pfcDetailed = pfcDetailed
        self.pfcConfidence = pfcConfidence
        self.attributedTo = attributedTo
        self.enteredByUid = enteredByUid
        self.status = status
        self.pendingTransactionId = pendingTransactionId
        self.recurringItemId = recurringItemId
        self.excludeFromBudget = excludeFromBudget
        self.isHidden = isHidden
        self.hiddenByUid = hiddenByUid
        self.notes = notes
        self.possibleDuplicateOf = possibleDuplicateOf
        self.mergedFromManualId = mergedFromManualId
        self.discussFlaggedByUid = discussFlaggedByUid
        self.discussNote = discussNote
        self.discussResolvedAt = discussResolvedAt
        self.splits = splits
    }

    /// Signed minor units: expenses negative, income positive. Convenience for
    /// net math; storage stays unsigned + direction.
    public var signedAmountMinor: Int {
        direction == .expense ? -amountMinor : amountMinor
    }

    /// An unresolved "Let's discuss" flag.
    public var isAwaitingDiscussion: Bool {
        discussFlaggedByUid != nil && discussResolvedAt == nil
    }
}
