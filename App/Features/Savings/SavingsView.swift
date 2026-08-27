import SwiftUI

/// Savings stub (PRD §4.5): the combined-progress hero and project cards
/// land with the Savings feature build.
struct SavingsView: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "sparkles",
                title: "Shared projects land here",
                message: "Progress you move forward together — \(repositories.savings.projects.count) demo projects are seeded."
            )
            .padding(.top, Theme.cardPadding * 3)
        }
        .background(Theme.background)
        .navigationTitle("Savings")
    }
}

#Preview {
    NavigationStack {
        SavingsView()
    }
    .environment(DemoSeed.makeRepositories())
}
