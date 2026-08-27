import SwiftUI

/// Expenses stub (PRD §4.3): the live-total hero and the merged, searchable
/// feed land with the Expenses feature build.
struct ExpensesView: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "list.bullet.rectangle.portrait",
                title: "The shared feed lands here",
                message: "One merged feed for both partners — \(transactionCount) demo transactions seeded."
            )
            .padding(.top, Theme.cardPadding * 3)
        }
        .background(Theme.background)
        .navigationTitle("Expenses")
    }

    private var transactionCount: Int {
        repositories.transactions.transactions.count
    }
}

#Preview {
    NavigationStack {
        ExpensesView()
    }
    .environment(DemoSeed.makeRepositories())
}
