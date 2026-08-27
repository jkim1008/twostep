import SwiftUI
import TwoStepCore

/// The Weekly Sync (PRD §4.7.1, demo-light): both partners consume the
/// identical digest of the most recently completed Monday–Sunday week.
/// Week bucketing comes from `WeekKey` and every number from `DigestBuilder`
/// — the view is a pure template over that output, exactly like the
/// materialized digest doc will be.
struct WeeklySyncView: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        ScrollView {
            if let digest {
                VStack(alignment: .leading, spacing: Theme.cardPadding) {
                    WeeklySyncHeaderView(
                        digest: digest,
                        members: repositories.households.members
                    )
                    inOutHero(digest)
                    WeeklySyncCategoriesSection(digest: digest)
                    WeeklySyncBillsSection(bills: digest.upcomingBills)
                    WeeklySyncDiscussSection()
                }
                .padding(.horizontal, Theme.cardPadding)
                .padding(.bottom, Theme.cardPadding * 5)
            } else {
                EmptyStateView(
                    systemImage: "calendar.badge.clock",
                    title: "No completed week yet",
                    message: "Your first Weekly Sync arrives once a full Monday–Sunday week is on the books."
                )
                .padding(.top, Theme.cardPadding * 3)
            }
        }
        .background(Theme.background)
        .navigationTitle("Weekly Sync")
    }

    // MARK: - Hero

    /// Total in / total out for the covered week — the digest's one hero.
    private func inOutHero(_ digest: WeeklyDigest) -> some View {
        HStack(spacing: Theme.cardSpacing) {
            inOutBlock(
                title: "In",
                accessibilityText: "in this week",
                amountMinor: digest.totalInMinor,
                systemImage: "arrow.down.circle.fill",
                iconColor: Theme.success
            )
            inOutBlock(
                title: "Out",
                accessibilityText: "out this week",
                amountMinor: digest.totalOutMinor,
                systemImage: "arrow.up.circle.fill",
                iconColor: Theme.textSecondary
            )
        }
    }

    private func inOutBlock(
        title: LocalizedStringKey,
        accessibilityText: String,
        amountMinor: Int,
        systemImage: String,
        iconColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)
                .tint(iconColor)
            Text(DemoDayText.currency(amountMinor))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(DemoDayText.currency(amountMinor)) \(accessibilityText)"))
    }

    // MARK: - Data

    /// The most recently completed week as of the pinned demo "today",
    /// built by the same `DigestBuilder` the Cloud Function will call.
    private var digest: WeeklyDigest? {
        guard let today = CalendarDay(dateString: DemoSeed.focusDate) else { return nil }
        let weekKey = WeekKey.lastCompletedWeekKey(asOf: today)
        return DigestBuilder.build(
            weekKey: weekKey,
            transactions: repositories.transactions.transactions,
            allocations: allocations(for: weekKey),
            recurringItems: repositories.recurring.items,
            upcomingWindowDays: 14
        )
    }

    /// Allocations of the month containing the week's Sunday — the same month
    /// the digest's pace figures are computed against.
    private func allocations(for weekKey: String) -> [String: Int] {
        guard let sunday = WeekKey.endDateString(of: weekKey),
              let month = MonthKey.key(forDateString: sunday),
              let budget = repositories.budgets.budget(forMonth: month)
        else { return [:] }
        return budget.allocations
    }
}

/// Digest header: the covered week plus both partners' seen-state avatars —
/// either partner can see, without asking, whether the other has read this
/// week's Sync (demo values: both have).
private struct WeeklySyncHeaderView: View {
    let digest: WeeklyDigest
    let members: [HouseholdMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week of \(DemoDayText.range(digest.startDate, digest.endDate))")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                ForEach(members) { member in
                    seenAvatar(for: member)
                }
                Text("Seen by both of you")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(seenSummary))
        }
    }

    private func seenAvatar(for member: HouseholdMember) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(Color(hexString: member.colorHex))
                    .frame(width: 28, height: 28)
                Text(member.displayName.prefix(1))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.success)
                .background(Theme.background, in: Circle())
                .offset(x: 3, y: 3)
        }
    }

    private var seenSummary: String {
        let names = members.map(\.displayName).joined(separator: " and ")
        return "Seen by \(names)"
    }
}

#Preview {
    NavigationStack {
        WeeklySyncView()
    }
    .environment(DemoSeed.makeRepositories())
}
