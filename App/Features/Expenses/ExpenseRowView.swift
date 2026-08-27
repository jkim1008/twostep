import SwiftUI
import TwoStepCore

/// One feed row (PRD §4.3): merchant, amount, category emoji + name chip,
/// partner attribution badge, and status markers (pending / internal /
/// flagged / hidden) — every marker is text or a labeled icon, never color
/// alone.
struct ExpenseRowView: View {
    @Environment(AppRepositories.self) private var repositories
    let transaction: TwoStepCore.Transaction

    var body: some View {
        HStack(alignment: .center, spacing: Theme.cardSpacing) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(verbatim: transaction.merchantName ?? String(localized: "Unknown merchant"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if transaction.status == .pending {
                        markerTag("Pending", color: Theme.info)
                    }
                    if transaction.isHidden {
                        markerTag("Hidden", color: Theme.textTertiary)
                    }
                }
                HStack(spacing: 6) {
                    if let category {
                        EmojiCategoryChip(emoji: category.emoji, name: category.name)
                    }
                    PartnerBadge(
                        name: repositories.households.displayName(for: transaction.attributedTo),
                        colorHex: repositories.households.badgeColorHex(for: transaction.attributedTo)
                    )
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                amountText
                HStack(spacing: 6) {
                    if transaction.excludeFromBudget, transaction.direction == .expense {
                        Text("Internal")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if transaction.isAwaitingDiscussion {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.primary)
                            .accessibilityLabel(Text("Flagged to discuss"))
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(transaction.isHidden ? 0.55 : 1)
    }

    /// Expenses render plain; income/refunds render with a leading plus in
    /// the success color (paired with the sign — color is never alone).
    private var amountText: some View {
        let amount = ExpenseFormat.money(transaction.amountMinor)
        let isIncome = transaction.direction == .income
        return Text(verbatim: isIncome ? "+\(amount)" : amount)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(isIncome ? Theme.success : Theme.textPrimary)
    }

    private func markerTag(_ label: LocalizedStringKey, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.surface, in: Capsule())
    }

    private var category: TransactionCategory? {
        guard let categoryId = transaction.categoryId else { return nil }
        return repositories.budgets.category(withId: categoryId)
    }
}

#Preview {
    let repositories = DemoSeed.makeRepositories()
    return List(repositories.transactions.transactions.prefix(8)) { transaction in
        ExpenseRowView(transaction: transaction)
    }
    .listStyle(.plain)
    .environment(repositories)
}
