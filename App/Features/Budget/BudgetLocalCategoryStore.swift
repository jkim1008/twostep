import Foundation
import Observation
import TwoStepCore

/// Session-scoped overlay for custom categories in the demo build.
///
/// Production category CRUD is server-side (categories are seeded and managed
/// through Cloud Functions), and the demo `BudgetRepository` protocol
/// deliberately exposes no category mutations. This overlay lets the PRD §4.4
/// create/edit/archive flow be demonstrated end-to-end: locally created
/// categories merge into every Budget surface, while their **allocations**
/// persist through the real repository (`setAllocation` keys by category id).
@MainActor
@Observable
final class BudgetLocalCategoryStore {
    private(set) var customCategories: [TransactionCategory] = []

    /// Chart palette (DESIGN.md §2.4) cycled across new custom categories.
    private static let paletteHexes = [
        "#6C91C2", "#EC4899", "#D97706", "#8B5CF6", "#4F9D69", "#6366F1"
    ]

    /// Seeded categories plus live (non-archived) custom ones.
    func displayCategories(base: [TransactionCategory]) -> [TransactionCategory] {
        base + customCategories.filter { !$0.isArchived }
    }

    @discardableResult
    func add(name: String, emoji: String) -> TransactionCategory {
        let colorHex = Self.paletteHexes[customCategories.count % Self.paletteHexes.count]
        let category = TransactionCategory(
            id: "custom-\(UUID().uuidString)",
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            isSystem: false
        )
        customCategories.append(category)
        return category
    }

    func update(id: String, name: String, emoji: String) {
        guard let index = customCategories.firstIndex(where: { $0.id == id }) else { return }
        customCategories[index].name = name
        customCategories[index].emoji = emoji
    }

    /// Archive, never delete (PRD §6.3) — history keeps referencing the id.
    func archive(id: String) {
        guard let index = customCategories.firstIndex(where: { $0.id == id }) else { return }
        customCategories[index].isArchived = true
    }

    func category(withId id: String) -> TransactionCategory? {
        customCategories.first { $0.id == id }
    }
}
