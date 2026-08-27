import SwiftUI
import TwoStepCore

/// Category drill-down (PRD §4.4): that month's transactions in the category,
/// under a live spent/allocated header. Spend figures always come from
/// `BudgetMath`, so this screen agrees with the donut to the cent.
struct BudgetCategoryDetailView: View {
    let item: BudgetCategoryItem
    let month: String
    let isEditable: Bool

    @Environment(AppRepositories.self) private var repositories
    @State private var allocationTarget: BudgetCategoryItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                header
                transactionsSection
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, Theme.cardPadding * 2)
        }
        .background(Theme.background)
        .navigationTitle("\(item.emoji) \(item.name)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $allocationTarget) { target in
            BudgetAllocationSheet(item: target, month: month)
        }
    }

    // MARK: Live math (recomputed so allocation edits reflect immediately)

    private var liveAllocationMinor: Int? {
        repositories.budgets.budget(forMonth: month)?.allocations[item.id]
    }

    private var liveItem: BudgetCategoryItem {
        let spent = BudgetMath.spentPerCategory(
            transactions: repositories.transactions.transactions,
            month: month
        )
        return BudgetCategoryItem(
            id: item.id,
            name: item.name,
            emoji: item.emoji,
            colorHex: item.colorHex,
            isCustom: item.isCustom,
            trueSpentMinor: spent[item.id] ?? 0,
            allocationMinor: liveAllocationMinor
        )
    }

    private var monthTransactions: [TwoStepCore.Transaction] {
        repositories.transactions.transactions
            .filter { transaction in
                guard BudgetMath.isBudgetEligible(transaction, month: month) else { return false }
                if transaction.splits.isEmpty {
                    return (transaction.categoryId ?? BudgetMath.uncategorizedCategoryId) == item.id
                }
                return transaction.splits.contains { ($0.categoryId ?? BudgetMath.uncategorizedCategoryId) == item.id }
            }
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spent in \(BudgetFormat.monthTitle(month))")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            HeroNumberView(amountMinor: liveItem.displaySpentMinor)
            if let allocation = liveItem.allocationMinor {
                ProgressBarView(spentMinor: liveItem.displaySpentMinor, allocationMinor: allocation)
                Text(allocationSummary(allocation: allocation))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Tracking only — no budget set this month.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if isEditable {
                Button {
                    allocationTarget = liveItem
                } label: {
                    Text(liveItem.allocationMinor == nil ? "Set budget" : "Edit budget")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 28)
                }
                .buttonStyle(.bordered)
                .tint(Theme.primary)
            } else {
                Text("Previous months' budgets are read-only.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.top, Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transactions")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 8)
            if monthTransactions.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "Nothing here yet",
                    message: "Transactions tagged to this category will appear for this month."
                )
            } else {
                ForEach(monthTransactions) { transaction in
                    BudgetTransactionRow(transaction: transaction)
                    Divider()
                        .overlay(Theme.separator)
                }
            }
        }
    }

    private func allocationSummary(allocation: Int) -> String {
        let remaining = allocation - liveItem.trueSpentMinor
        let spent = BudgetFormat.currency(liveItem.displaySpentMinor)
        let budget = BudgetFormat.compactCurrency(allocation)
        return remaining >= 0
            ? "\(spent) of \(budget) — \(BudgetFormat.currency(remaining)) left"
            : "\(spent) of \(budget) — over by \(BudgetFormat.currency(-remaining))"
    }
}

/// One transaction line in the drill-down: merchant, date, attribution badge,
/// signed amount (refunds show as credits).
private struct BudgetTransactionRow: View {
    let transaction: TwoStepCore.Transaction

    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName ?? transaction.originalDescription ?? "Transaction")
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(BudgetFormat.shortDay(transaction.date))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    if transaction.status == .pending {
                        Text("Pending")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    PartnerBadge(
                        name: repositories.households.displayName(for: transaction.attributedTo),
                        colorHex: repositories.households.badgeColorHex(for: transaction.attributedTo)
                    )
                }
            }
            Spacer(minLength: 8)
            Text(amountText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.direction == .income ? Theme.success : Theme.textPrimary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        let base = BudgetFormat.currency(transaction.amountMinor)
        return transaction.direction == .income ? "+\(base)" : base
    }
}

#Preview {
    NavigationStack {
        BudgetCategoryDetailView(
            item: BudgetCategoryItem(
                id: "groceries", name: "Groceries", emoji: "🛒", colorHex: "#F97316",
                isCustom: false, trueSpentMinor: 512_40, allocationMinor: 650_00
            ),
            month: DemoSeed.focusMonth,
            isEditable: true
        )
    }
    .environment(DemoSeed.makeRepositories())
}
