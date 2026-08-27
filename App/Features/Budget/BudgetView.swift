import SwiftUI

/// Budget stub (PRD §4.4): the donut hero and per-category list land with
/// the Budget feature build. Budgeting is opt-in per category; tracking is
/// universal.
struct BudgetView: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "chart.pie",
                title: "The budget donut lands here",
                message: "Category share of spend, total centered — \(allocationCount) categories carry August allocations."
            )
            .padding(.top, Theme.cardPadding * 3)
        }
        .background(Theme.background)
        .navigationTitle("Budget")
    }

    private var allocationCount: Int {
        repositories.budgets.budget(forMonth: DemoSeed.focusMonth)?.allocations.count ?? 0
    }
}

#Preview {
    NavigationStack {
        BudgetView()
    }
    .environment(DemoSeed.makeRepositories())
}
