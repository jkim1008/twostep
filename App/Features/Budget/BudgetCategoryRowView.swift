import SwiftUI
import TwoStepCore

/// One category line in the Budget list. Allocated categories render the
/// threshold progress bar; unallocated categories show spend plainly with a
/// "Set budget" affordance (PRD §4.4: budgeting is opt-in, tracking is
/// universal). Color is never the only signal — every state carries text.
struct BudgetCategoryRowView: View {
    let item: BudgetCategoryItem
    /// Whether this month's allocations are editable (current month only).
    let isEditable: Bool
    let onSetBudget: () -> Void

    var body: some View {
        if item.allocationMinor != nil {
            allocatedRow
        } else {
            unallocatedRow
        }
    }

    // MARK: Allocated

    private var allocatedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                titleLabel
                Spacer(minLength: 8)
                Text(spentOfAllocatedText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            ProgressBarView(spentMinor: item.displaySpentMinor, allocationMinor: item.allocationMinor)
            HStack {
                Text(percentText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                remainingLabel
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(allocatedAccessibilityText))
    }

    // MARK: Unallocated

    private var unallocatedRow: some View {
        HStack(spacing: 8) {
            titleLabel
            Spacer(minLength: 8)
            Text(BudgetFormat.currency(item.displaySpentMinor))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            if isEditable {
                Button(action: onSetBudget) {
                    Text("Set budget")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.primaryTint, in: Capsule())
                        .foregroundStyle(Theme.primaryDark)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(Text("Set a budget for \(item.name)"))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: Pieces

    private var titleLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hexString: item.colorHex))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(item.emoji)
                .accessibilityHidden(true)
            Text(item.name)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var remainingLabel: some View {
        if let allocation = item.allocationMinor {
            let remaining = allocation - item.trueSpentMinor
            if remaining >= 0 {
                Text("\(BudgetFormat.currency(remaining)) left")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Over by \(BudgetFormat.currency(-remaining))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    private var spentOfAllocatedText: String {
        let allocation = item.allocationMinor ?? 0
        let spent = BudgetFormat.currency(item.displaySpentMinor)
        return "\(spent) of \(BudgetFormat.compactCurrency(allocation))"
    }

    private var percentValue: Int {
        guard let allocation = item.allocationMinor, allocation > 0 else { return 0 }
        return (item.displaySpentMinor * 100 + allocation / 2) / allocation
    }

    private var percentText: String {
        "\(percentValue)% spent"
    }

    private var allocatedAccessibilityText: String {
        "\(item.name), \(spentOfAllocatedText), \(percentValue) percent of budget spent"
    }
}

#Preview {
    VStack(spacing: 0) {
        BudgetCategoryRowView(
            item: BudgetCategoryItem(
                id: "groceries", name: "Groceries", emoji: "🛒", colorHex: "#F97316",
                isCustom: false, trueSpentMinor: 512_40, allocationMinor: 650_00
            ),
            isEditable: true,
            onSetBudget: {}
        )
        BudgetCategoryRowView(
            item: BudgetCategoryItem(
                id: "shopping", name: "Shopping", emoji: "🛍️", colorHex: "#D97706",
                isCustom: false, trueSpentMinor: 214_10, allocationMinor: nil
            ),
            isEditable: true,
            onSetBudget: {}
        )
    }
    .padding()
    .background(Theme.background)
}
