import SwiftUI
import TwoStepCore

/// Dashboard stub (PRD §4.8) — home surface, month-scoped. The hero (total
/// spent so far this month) is real and wired to the repositories; the
/// remaining modules land with the Dashboard feature build.
struct DashboardView: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                Text("Spent so far this month")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                HeroNumberView(amountMinor: BudgetMath.displaySpent(totalSpentMinor))
                    .accessibilityIdentifier("root.dashboard")

                NavigationLink {
                    WeeklySyncView()
                } label: {
                    Label("This week's Sync", systemImage: "calendar.badge.clock")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, Theme.cardPadding)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                }
                .foregroundStyle(Theme.textPrimary)

                Text("At-risk budgets, upcoming bills, projects, and the to-discuss queue land here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Theme.cardPadding)
        }
        .background(Theme.background)
        .navigationTitle("Dashboard")
    }

    private var totalSpentMinor: Int {
        BudgetMath.totalSpent(
            transactions: repositories.transactions.transactions,
            month: DemoSeed.focusMonth
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(DemoSeed.makeRepositories())
}
