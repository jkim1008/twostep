import SwiftUI
import TwoStepCore

/// At-risk budget categories (PRD §4.8): allocated categories running ahead
/// of pace or near/over their allocation, per `BudgetMath.atRiskCategoryIds`.
/// Categories without an allocation never appear here (§4.4 stance — no
/// on/off-track state without an allocation). Navigates into the Budget tool.
struct DashboardAtRiskModule: View {
    @Environment(AppRepositories.self) private var repositories
    let month: String
    let today: String

    var body: some View {
        NavigationLink {
            BudgetView()
        } label: {
            DashboardCard(title: "At-risk budgets") {
                if rows.isEmpty {
                    Text("All budgeted categories are on track.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(rows, id: \.category.id) { row in
                        atRiskRow(row)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens the Budget tool"))
    }

    // MARK: Rows

    private struct AtRiskRow {
        let category: TransactionCategory
        let spentMinor: Int
        let allocationMinor: Int
    }

    private func atRiskRow(_ row: AtRiskRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                EmojiCategoryChip(emoji: row.category.emoji, name: row.category.name)
                Spacer()
                // Threshold state is always paired with text — never color alone.
                Text(verbatim: spentLabel(row))
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressBarView(
                spentMinor: BudgetMath.displaySpent(row.spentMinor),
                allocationMinor: row.allocationMinor
            )
        }
        .padding(.vertical, 2)
    }

    private func spentLabel(_ row: AtRiskRow) -> String {
        let spent = DashboardFormat.money(BudgetMath.displaySpent(row.spentMinor))
        let allocated = DashboardFormat.money(row.allocationMinor)
        return "\(spent) of \(allocated)"
    }

    /// Allocated categories the tested at-risk formula flags, worst first.
    private var rows: [AtRiskRow] {
        guard let day = CalendarDay(dateString: today) else { return [] }
        let spent = BudgetMath.spentPerCategory(
            transactions: repositories.transactions.transactions,
            month: month
        )
        let allocations = repositories.budgets.budget(forMonth: month)?.allocations ?? [:]
        let atRisk = BudgetMath.atRiskCategoryIds(
            spent: spent,
            allocations: allocations,
            daysElapsed: day.day,
            daysInMonth: MonthKey.daysIn(month: day.month, year: day.year)
        )
        return atRisk
            .filter { (allocations[$0] ?? 0) > 0 }
            .compactMap { categoryId -> AtRiskRow? in
                guard let category = repositories.budgets.category(withId: categoryId) else { return nil }
                return AtRiskRow(
                    category: category,
                    spentMinor: spent[categoryId] ?? 0,
                    allocationMinor: allocations[categoryId] ?? 0
                )
            }
            // Worst overshoot first: compare spent/allocation ratios via
            // integer cross-multiplication (no floats in money math).
            .sorted { $0.spentMinor * $1.allocationMinor > $1.spentMinor * $0.allocationMinor }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DashboardAtRiskModule(month: DemoSeed.focusMonth, today: DemoSeed.focusDate)
                .padding()
        }
        .background(Theme.background)
    }
    .environment(DemoSeed.makeRepositories())
}
