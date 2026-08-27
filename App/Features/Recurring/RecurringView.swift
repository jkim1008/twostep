import SwiftUI

/// Recurring stub (PRD §4.6): the calendar hero (month grid with payment
/// chips) and the agenda beneath land with the Recurring feature build.
struct RecurringView: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "calendar",
                title: "The bills calendar lands here",
                message: "A month grid with payment chips — \(upcomingCount) demo bills are due in the next 30 days."
            )
            .padding(.top, Theme.cardPadding * 3)
        }
        .background(Theme.background)
        .navigationTitle("Recurring")
    }

    private var upcomingCount: Int {
        repositories.recurring.upcomingItems(onOrAfter: DemoSeed.focusDate).count
    }
}

#Preview {
    NavigationStack {
        RecurringView()
    }
    .environment(DemoSeed.makeRepositories())
}
