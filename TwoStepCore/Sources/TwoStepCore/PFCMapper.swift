import Foundation

/// Mapping Plaid's personal-finance categories (PFC) onto household categories
/// (PRD §4.3 flow 1).
///
/// Rules:
/// - Each of Plaid's 16 PFC primaries has a seeded default category (name,
///   emoji identity, color, exclude-from-budget default). `INCOME`,
///   `TRANSFER_IN`, `TRANSFER_OUT`, and `LOAN_PAYMENTS` default to
///   `excludeFromBudget = true` — ordinary income and internal transfers never
///   move spending rings.
/// - Confidence threshold: `LOW`, `VERY_LOW`, or missing confidence →
///   needs-review (categorized by normal precedence *and also* flagged).
///   `UNKNOWN` (or an unmapped primary) → no default category (Uncategorized),
///   which lands in review via the uncategorized path.
/// - The raw PFC triple is stored on every transaction, so this mapping can be
///   re-run retroactively when the table changes.
public enum PFCMapper {
    /// A seeded default category for one PFC primary.
    public struct DefaultCategory: Hashable, Sendable {
        public let name: String
        /// The category's primary identity (see `TransactionCategory.emoji`).
        public let emoji: String
        public let colorHex: String
        public let excludeFromBudgetByDefault: Bool

        public init(name: String, emoji: String, colorHex: String, excludeFromBudgetByDefault: Bool) {
            self.name = name
            self.emoji = emoji
            self.colorHex = colorHex
            self.excludeFromBudgetByDefault = excludeFromBudgetByDefault
        }
    }

    /// Plaid PFC confidence levels, in the wire spelling.
    public enum Confidence: String, Sendable {
        case veryHigh = "VERY_HIGH"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
        case veryLow = "VERY_LOW"
        case unknown = "UNKNOWN"
    }

    /// Plaid's 16 PFC primaries → seeded default categories, keyed by the
    /// wire spelling of the primary.
    public static let defaultCategories: [String: DefaultCategory] = [
        "INCOME": .init(name: "Income", emoji: "💰", colorHex: "#4CAF93", excludeFromBudgetByDefault: true),
        "TRANSFER_IN": .init(name: "Transfers In", emoji: "📥", colorHex: "#8E9AAF", excludeFromBudgetByDefault: true),
        "TRANSFER_OUT": .init(name: "Transfers Out", emoji: "📤", colorHex: "#8E9AAF", excludeFromBudgetByDefault: true),
        "LOAN_PAYMENTS": .init(name: "Loan Payments", emoji: "🏦", colorHex: "#7A6FF0", excludeFromBudgetByDefault: true),
        "BANK_FEES": .init(name: "Bank Fees", emoji: "🧾", colorHex: "#B0784A", excludeFromBudgetByDefault: false),
        "ENTERTAINMENT": .init(name: "Entertainment", emoji: "🎬", colorHex: "#E2637F", excludeFromBudgetByDefault: false),
        "FOOD_AND_DRINK": .init(name: "Food & Drink", emoji: "🍽️", colorHex: "#F2A65A", excludeFromBudgetByDefault: false),
        "GENERAL_MERCHANDISE": .init(name: "Shopping", emoji: "🛍️", colorHex: "#C98BDB", excludeFromBudgetByDefault: false),
        "HOME_IMPROVEMENT": .init(name: "Home", emoji: "🔨", colorHex: "#A9845C", excludeFromBudgetByDefault: false),
        "MEDICAL": .init(name: "Medical", emoji: "🩺", colorHex: "#5CA9C9", excludeFromBudgetByDefault: false),
        "PERSONAL_CARE": .init(name: "Personal Care", emoji: "💇", colorHex: "#DB8BA9", excludeFromBudgetByDefault: false),
        "GENERAL_SERVICES": .init(name: "Services", emoji: "🛠️", colorHex: "#8AA84F", excludeFromBudgetByDefault: false),
        "GOVERNMENT_AND_NON_PROFIT": .init(
            name: "Government & Donations", emoji: "🏛️", colorHex: "#6F8AB7", excludeFromBudgetByDefault: false),
        "TRANSPORTATION": .init(name: "Transportation", emoji: "🚗", colorHex: "#4FA8A8", excludeFromBudgetByDefault: false),
        "TRAVEL": .init(name: "Travel", emoji: "✈️", colorHex: "#5C8ADB", excludeFromBudgetByDefault: false),
        "RENT_AND_UTILITIES": .init(name: "Rent & Utilities", emoji: "🏠", colorHex: "#C9A25C", excludeFromBudgetByDefault: false)
    ]

    /// Default category for a PFC primary, or nil for `UNKNOWN`/unmapped
    /// primaries (→ Uncategorized).
    public static func defaultCategory(forPrimary primary: String?) -> DefaultCategory? {
        guard let primary else { return nil }
        return defaultCategories[primary]
    }

    /// The confidence threshold rule: `LOW`, `VERY_LOW`, missing, or
    /// unparseable confidence flags the transaction into needs-review.
    /// (`UNKNOWN` also flags — it lands uncategorized, which is a review state
    /// by definition.) `MEDIUM` and above pass.
    public static func needsReview(confidence rawConfidence: String?) -> Bool {
        guard let rawConfidence, let confidence = Confidence(rawValue: rawConfidence) else {
            return true
        }
        return switch confidence {
        case .veryHigh, .high, .medium: false
        case .low, .veryLow, .unknown: true
        }
    }

    /// PFC primaries that are internal money movement, not real spending —
    /// excluded from budget math and from dashboard in/out totals (R17).
    public static func isInternalTransfer(primary: String?) -> Bool {
        guard let primary else { return false }
        return primary == "TRANSFER_IN" || primary == "TRANSFER_OUT" || primary == "LOAN_PAYMENTS"
    }
}
