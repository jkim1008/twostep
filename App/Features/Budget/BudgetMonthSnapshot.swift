import Foundation
import SwiftUI
import TwoStepCore

/// One category's line in the Budget tool for one month. Spend figures come
/// from `BudgetMath` — never recomputed in views.
struct BudgetCategoryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let colorHex: String
    let isCustom: Bool
    /// True (possibly negative) net spend, minor units.
    let trueSpentMinor: Int
    /// nil = unallocated this month (tracking only — PRD §4.4 stance).
    let allocationMinor: Int?

    /// Display value, floored at zero (refund-heavy categories show $0).
    var displaySpentMinor: Int { BudgetMath.displaySpent(trueSpentMinor) }
}

/// Everything the Budget screen renders for one month, derived in one place
/// from the repositories' raw state via TwoStepCore's tested math.
struct BudgetMonthSnapshot {
    let month: String
    /// Categories with an allocation this month, largest spend first.
    let allocatedItems: [BudgetCategoryItem]
    /// Categories tracking spend without an allocation, largest spend first.
    let unallocatedItems: [BudgetCategoryItem]

    init(
        month: String,
        categories: [TransactionCategory],
        excludedCategoryIds: Set<String>,
        allocations: [String: Int],
        transactions: [TwoStepCore.Transaction]
    ) {
        self.month = month
        let spent = BudgetMath.spentPerCategory(transactions: transactions, month: month)
        var allocated: [BudgetCategoryItem] = []
        var unallocated: [BudgetCategoryItem] = []

        for category in categories where !category.isArchived && !excludedCategoryIds.contains(category.id) {
            let allocation = allocations[category.id]
            let trueSpent = spent[category.id] ?? 0
            guard allocation != nil || trueSpent != 0 else { continue }
            let item = BudgetCategoryItem(
                id: category.id,
                name: category.name,
                emoji: category.emoji,
                colorHex: category.colorHex,
                isCustom: !category.isSystem,
                trueSpentMinor: trueSpent,
                allocationMinor: allocation
            )
            if allocation != nil {
                allocated.append(item)
            } else {
                unallocated.append(item)
            }
        }

        // Eligible spend on transactions nobody categorized yet still counts.
        if let uncategorizedSpent = spent[BudgetMath.uncategorizedCategoryId], uncategorizedSpent != 0 {
            unallocated.append(BudgetCategoryItem(
                id: BudgetMath.uncategorizedCategoryId,
                name: "Uncategorized",
                emoji: "❓",
                colorHex: "#98A091",
                isCustom: false,
                trueSpentMinor: uncategorizedSpent,
                allocationMinor: allocations[BudgetMath.uncategorizedCategoryId]
            ))
        }

        allocatedItems = Self.sorted(allocated)
        unallocatedItems = Self.sorted(unallocated)
    }

    /// The hero numeral: sum of every displayed (floored) spend figure — by
    /// construction it always equals the sum of the donut's slice values.
    var totalDisplaySpentMinor: Int {
        (allocatedItems + unallocatedItems).reduce(0) { $0 + $1.displaySpentMinor }
    }

    /// Donut slices: every category with positive display spend, colored by
    /// the category's chart color (DESIGN.md §2.4), labeled emoji + name.
    var donutSegments: [DonutSegment] {
        (allocatedItems + unallocatedItems)
            .filter { $0.displaySpentMinor > 0 }
            .sorted { $0.displaySpentMinor > $1.displaySpentMinor }
            .map { item in
                DonutSegment(
                    id: item.id,
                    value: Double(item.displaySpentMinor),
                    color: Color(hexString: item.colorHex),
                    label: "\(item.emoji) \(item.name), \(BudgetFormat.currency(item.displaySpentMinor))"
                )
            }
    }

    var isEmpty: Bool {
        allocatedItems.isEmpty && unallocatedItems.isEmpty
    }

    private static func sorted(_ items: [BudgetCategoryItem]) -> [BudgetCategoryItem] {
        items.sorted {
            ($0.displaySpentMinor, $1.name) > ($1.displaySpentMinor, $0.name)
        }
    }
}

/// Display-boundary formatting and parsing for the Budget feature. All money
/// stays integer minor units; `Decimal` appears only here (via `Money`).
enum BudgetFormat {
    static func currency(_ amountMinor: Int) -> String {
        Money(amountMinor: amountMinor).decimalValue.formatted(.currency(code: "USD"))
    }

    /// Whole-dollar rendering for allocations ("$650"), cents kept when present.
    static func compactCurrency(_ amountMinor: Int) -> String {
        let digits = amountMinor % 100 == 0 ? 0 : 2
        return Money(amountMinor: amountMinor).decimalValue
            .formatted(.currency(code: "USD").precision(.fractionLength(digits)))
    }

    /// `"2026-08"` → `"August 2026"`.
    static func monthTitle(_ monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]),
              (1...12).contains(month)
        else { return monthKey }
        return "\(DateFormatter().monthSymbols[month - 1]) \(year)"
    }

    /// `"2026-08-16"` → `"Aug 16"`.
    static func shortDay(_ dateString: String) -> String {
        guard let day = CalendarDay(dateString: dateString) else { return dateString }
        return "\(DateFormatter().shortMonthSymbols[day.month - 1]) \(day.day)"
    }

    /// Editable dollars string for a stored allocation ("650" or "650.50").
    static func editableAmount(_ amountMinor: Int) -> String {
        let dollars = amountMinor / 100
        let cents = amountMinor % 100
        return cents == 0 ? "\(dollars)" : String(format: "%d.%02d", dollars, cents)
    }

    /// Parses user dollars input to minor units via `Money`'s canonical
    /// rounding. Returns nil for empty, malformed, or negative input.
    static func minorUnits(fromInput input: String) -> Int? {
        let cleaned = input
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let decimal = Decimal(string: cleaned), decimal >= 0 else {
            return nil
        }
        return Money(decimal: decimal).amountMinor
    }
}
