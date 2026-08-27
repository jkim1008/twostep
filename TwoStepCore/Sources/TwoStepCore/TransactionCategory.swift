import Foundation

/// A household spending category.
///
/// Invariants (PRD §6.3):
/// - The **emoji is the category's primary visual identity** — every surface
///   (feed chips, budget cards, digest rows) renders the emoji first; the name
///   is the label beside it.
/// - Categories archive, never delete: transactions reference them forever.
/// - `pfcMappings` holds the Plaid personal-finance-category codes (detailed
///   and/or primary) that auto-categorize into this category, so
///   "restaurants vs. groceries" can be split later without code changes.
/// - `isSystem` marks the seeded defaults (16 PFC primaries incl. Income);
///   system categories can be archived but not renamed away from their role.
public struct TransactionCategory: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public var name: String
    /// Primary identity — a single emoji scalar cluster (e.g. "🍽️").
    public var emoji: String
    public var colorHex: String
    public var isSystem: Bool
    public var isArchived: Bool
    /// Plaid PFC codes (detailed and/or primary) that map here.
    public var pfcMappings: [String]

    public init(
        id: String,
        name: String,
        emoji: String,
        colorHex: String,
        isSystem: Bool = false,
        isArchived: Bool = false,
        pfcMappings: [String] = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.isArchived = isArchived
        self.pfcMappings = pfcMappings
    }
}
