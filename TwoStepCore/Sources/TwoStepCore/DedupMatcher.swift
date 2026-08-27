import Foundation

/// Manual/import duplicate matching — the crux of "automated default + manual
/// supported" (PRD §4.3). The same matcher runs in both orderings: at import
/// against recent manual entries, and at manual save against existing imports.
///
/// Decision table (evaluated top-down; first hit wins):
///
/// | # | Condition                                                        | Verdict |
/// |---|------------------------------------------------------------------|---------|
/// | 1 | either transaction sits on a cash account                        | .none   |
/// | 2 | directions differ                                                | .none   |
/// | 3 | `amountMinor` not exactly equal                                  | .none   |
/// | 4 | |date delta| > 3 days (or either date malformed)                 | .none   |
/// | 5 | manual specified an account and it differs from the import's     | .none   |
/// | 6 | merchant fuzzy match succeeds                                    | .high   |
/// | 7 | otherwise (merchant missing on either side, or no fuzzy match)   | .medium |
///
/// Consequences (enforced by callers, R16): `.high` → auto-merge (import side)
/// or pre-write "same purchase?" sheet (manual side); `.medium` → write with
/// `possibleDuplicateOf` and surface a merge chip; never silently drop either
/// record.
public enum DedupMatcher {
    public enum Confidence: String, Sendable {
        case high
        case medium
        case none
    }

    /// Date window: manual entry and import may differ by at most this many days.
    public static let dateWindowDays = 3

    /// Confidence that `manual` and `imported` describe the same purchase.
    /// - Parameter cashAccountIds: ids of cash-type accounts; entries on them
    ///   are exempt from matching in both directions.
    public static func confidence(
        manual: Transaction,
        imported: Transaction,
        cashAccountIds: Set<String>
    ) -> Confidence {
        // 1. Cash exemption — cash spending legitimately mirrors card spending.
        if let manualAccount = manual.accountId, cashAccountIds.contains(manualAccount) {
            return .none
        }
        if let importedAccount = imported.accountId, cashAccountIds.contains(importedAccount) {
            return .none
        }
        // 2–3. Same direction, exact amount.
        guard manual.direction == imported.direction,
              manual.amountMinor == imported.amountMinor
        else { return .none }
        // 4. Date window.
        guard let manualDay = CalendarDay(dateString: manual.date),
              let importedDay = CalendarDay(dateString: imported.date),
              abs(manualDay.days(since: importedDay)) <= dateWindowDays
        else { return .none }
        // 5. Same account when the manual entry specified one.
        if let manualAccount = manual.accountId, manualAccount != imported.accountId {
            return .none
        }
        // 6–7. Merchant fuzzy match is the high/medium tiebreak.
        let importedMerchant = imported.merchantName ?? imported.originalDescription
        return merchantsFuzzyMatch(manual.merchantName, importedMerchant) ? .high : .medium
    }

    /// Case-, punctuation-, and spacing-insensitive merchant comparison:
    /// true when one normalized name contains the other, or when they share a
    /// distinctive token (≥ 4 characters). Returns false when either side is
    /// missing or normalizes to empty.
    public static func merchantsFuzzyMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        let leftTokens = tokens(of: lhs)
        let rightTokens = tokens(of: rhs)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }
        let leftJoined = leftTokens.joined()
        let rightJoined = rightTokens.joined()
        if leftJoined.contains(rightJoined) || rightJoined.contains(leftJoined) {
            return true
        }
        return !Set(leftTokens)
            .intersection(rightTokens)
            .filter { $0.count >= 4 }
            .isEmpty
    }

    // MARK: - Private

    private static func tokens(of merchant: String) -> [String] {
        merchant
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .map(String.init)
    }
}
