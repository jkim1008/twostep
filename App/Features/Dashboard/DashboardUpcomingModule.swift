import SwiftUI
import TwoStepCore

/// Soonest upcoming recurring payments (PRD §4.8): the next few due items
/// with date, amount, and attribution. Navigates into the Recurring calendar.
struct DashboardUpcomingModule: View {
    @Environment(AppRepositories.self) private var repositories
    let today: String
    /// How many rows the strip shows before deferring to the calendar.
    var limit: Int = 3

    var body: some View {
        NavigationLink {
            RecurringView()
        } label: {
            DashboardCard(title: "Upcoming bills") {
                if upcoming.isEmpty {
                    Text("No upcoming bills yet — add recurring items in the Recurring tab.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(upcoming) { item in
                        upcomingRow(item)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens the Recurring calendar"))
    }

    private func upcomingRow(_ item: RecurringItem) -> some View {
        HStack(alignment: .center, spacing: Theme.cardSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.merchant)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(verbatim: "Due \(DashboardFormat.shortDate(item.nextDueDate))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: DashboardFormat.money(item.amountMinor))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                PartnerBadge(
                    name: repositories.households.displayName(for: item.attributedTo),
                    colorHex: repositories.households.badgeColorHex(for: item.attributedTo)
                )
            }
        }
        .padding(.vertical, 2)
    }

    /// Active items due on or after the demo "today", soonest first.
    private var upcoming: [RecurringItem] {
        Array(repositories.recurring.upcomingItems(onOrAfter: today).prefix(limit))
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DashboardUpcomingModule(today: DemoSeed.focusDate)
                .padding()
        }
        .background(Theme.background)
    }
    .environment(DemoSeed.makeRepositories())
}
