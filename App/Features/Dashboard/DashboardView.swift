import SwiftUI
import TwoStepCore

/// Dashboard (PRD §4.8) — the month-scoped home surface answering "are we
/// okay this month?". Hero: total spent so far this month (same tested spend
/// formula as Budget/Expenses) with the net in/out line beneath; then the
/// at-risk budgets, upcoming bills, savings snapshot, and to-discuss modules,
/// each navigating into its owning tool. No donut here — it lives in Budget.
struct DashboardView: View {
    @Environment(AppRepositories.self) private var repositories

    private let month = DemoSeed.focusMonth
    private let today = DemoSeed.focusDate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                heroSection
                DashboardAtRiskModule(month: month, today: today)
                DashboardUpcomingModule(today: today)
                DashboardSavingsRow()
                DashboardDiscussRow()
            }
            .padding(Theme.cardPadding)
        }
        .background(Theme.background)
        .navigationTitle("Dashboard")
    }

    // MARK: Hero (DESIGN.md §5.4 — full-bleed, nothing stacked above it)

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spent so far this month")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            HeroNumberView(amountMinor: BudgetMath.displaySpent(totalSpentMinor))
                .accessibilityIdentifier("root.dashboard")
            netLine
        }
        .padding(.bottom, 4)
    }

    private var netLine: some View {
        let flow = monthFlow
        let net = flow.totalIn - flow.totalOut
        let netText = (net < 0 ? "−" : "+") + DashboardFormat.money(abs(net))
        return Text(verbatim: "Net \(netText) · In \(DashboardFormat.money(flow.totalIn)) · Out \(DashboardFormat.money(flow.totalOut))")
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(Theme.textTertiary)
            .accessibilityLabel(Text("Net this month \(netText)"))
    }

    // MARK: Month math

    /// Hero figure: `BudgetMath.totalSpent` — the same tested spend formula
    /// as the Budget and Expenses heroes (acceptance: they must match).
    private var totalSpentMinor: Int {
        BudgetMath.totalSpent(transactions: repositories.transactions.transactions, month: month)
    }

    /// Net in/out (PRD §4.8): Σ(income) − Σ(expense) over non-hidden,
    /// non-internal-transfer transactions this month. Internal detection uses
    /// `PFCMapper.isInternalTransfer` — on the raw PFC primary where present,
    /// and through the category's PFC mappings for rows without one.
    private var monthFlow: (totalIn: Int, totalOut: Int) {
        let internalIds = internalCategoryIds
        var totalIn = 0
        var totalOut = 0
        for transaction in repositories.transactions.transactions(inMonth: month)
        where !transaction.isHidden && !isInternalTransfer(transaction, internalCategoryIds: internalIds) {
            switch transaction.direction {
            case .income: totalIn += transaction.amountMinor
            case .expense: totalOut += transaction.amountMinor
            }
        }
        return (totalIn, totalOut)
    }

    private func isInternalTransfer(_ transaction: TwoStepCore.Transaction, internalCategoryIds: Set<String>) -> Bool {
        if PFCMapper.isInternalTransfer(primary: transaction.pfcPrimary) { return true }
        guard let categoryId = transaction.categoryId else { return false }
        return internalCategoryIds.contains(categoryId)
    }

    /// Categories whose PFC mappings are internal-transfer primaries
    /// (Transfers / loan payments) — data-driven, no hardcoded ids.
    private var internalCategoryIds: Set<String> {
        Set(
            repositories.budgets.categories
                .filter { category in
                    category.pfcMappings.contains { PFCMapper.isInternalTransfer(primary: $0) }
                }
                .map(\.id)
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(DemoSeed.makeRepositories())
}
