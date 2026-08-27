import SwiftUI

/// Weekly Sync stub (PRD §4.7.1): the flagship ritual — one identical
/// financial picture for both partners, once a week. The digest content and
/// seen-state land with the Weekly Sync feature build.
struct WeeklySyncView: View {
    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "calendar.badge.clock",
                title: "The Weekly Sync lands here",
                message: "In and out totals, top categories, bills, and the to-discuss queue — the same picture on both phones."
            )
            .padding(.top, Theme.cardPadding * 3)
        }
        .background(Theme.background)
        .navigationTitle("Weekly Sync")
    }
}

#Preview {
    NavigationStack {
        WeeklySyncView()
    }
    .environment(DemoSeed.makeRepositories())
}
