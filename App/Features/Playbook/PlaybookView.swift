import SwiftUI
import TwoStepCore

/// The Playbook (PRD §4.10): the household command center behind the header
/// avatar — never a tab. Household & partner management, linked banks,
/// categories & allocations at a glance, notification preferences, and the
/// boring-but-complete about section.
struct PlaybookView: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    // Demo-local notification preferences (PRD §4.10 stores these on the
    // household doc; the demo keeps them as view state).
    @State private var weeklySyncReminder = true
    @State private var billReminders = true
    @State private var budgetAlerts = false

    var body: some View {
        NavigationStack {
            List {
                householdSection
                inviteSection
                linkedBanksSection
                PlaybookCategoriesSection()
                notificationsSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton }
        }
    }

    // MARK: - Sections

    private var householdSection: some View {
        Section("Household") {
            LabeledContent("Name") {
                Text(repositories.households.household.name)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(repositories.households.members) { member in
                PlaybookMemberRowView(
                    member: member,
                    isCurrent: member.id == repositories.households.currentMember?.id
                )
            }
        }
    }

    private var inviteSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: "TWO-STEP-7B4K")
                    .font(.body.weight(.semibold))
                    .monospaced()
                    .foregroundStyle(Theme.primaryDark)
            } label: {
                Label("Invite partner", systemImage: "person.crop.circle.badge.plus")
                    .foregroundStyle(Theme.textPrimary)
            }
        } footer: {
            Text("Demo invite code — sharing is disabled in this preview build.")
        }
    }

    private var linkedBanksSection: some View {
        Section("Linked banks") {
            ForEach(DemoAccountsCatalog.accounts.filter { !$0.isCash }) { account in
                PlaybookBankRowView(
                    account: account,
                    ownerName: repositories.households.displayName(for: account.ownedBy),
                    ownerColorHex: repositories.households.badgeColorHex(for: account.ownedBy)
                )
            }
            LabeledContent {
                Text("Coming with Plaid")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            } label: {
                Label("Connect a bank", systemImage: "plus.circle")
                    .foregroundStyle(Theme.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Not available yet"))
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            LabeledContent("Weekly Sync") {
                Text(weeklySyncScheduleText)
                    .foregroundStyle(Theme.textSecondary)
            }
            Toggle("Weekly Sync reminder", isOn: $weeklySyncReminder)
            Toggle("Bill reminders", isOn: $billReminders)
            Toggle("Budget alerts", isOn: $budgetAlerts)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(versionText)
                    .foregroundStyle(Theme.textSecondary)
            }
            LabeledContent("Privacy policy") {
                Text("On our website")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("Two Step — money for households of exactly two. Export and account deletion arrive with real accounts.")
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: - Derived

    /// "Sunday, 7:00 PM" from the household schedule (1 = Monday … 7 = Sunday).
    private var weeklySyncScheduleText: String {
        let schedule = repositories.households.household.weeklySync
        let symbols = Calendar.current.weekdaySymbols // Sunday-first
        let sundayFirstIndex = schedule.weekday % 7   // Monday(1) → 1 … Sunday(7) → 0
        let dayName = symbols.indices.contains(sundayFirstIndex) ? symbols[sundayFirstIndex] : ""
        var components = DateComponents()
        components.hour = schedule.hour
        components.minute = schedule.minute
        let time = Calendar.current.date(from: components)
            .map { $0.formatted(date: .omitted, time: .shortened) }
        return "\(dayName), \(time ?? "\(schedule.hour):\(schedule.minute)")"
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(version ?? "1.0") (demo)"
    }
}

// MARK: - Rows

private struct PlaybookMemberRowView: View {
    let member: HouseholdMember
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: Theme.cardSpacing) {
            ZStack {
                Circle()
                    .fill(Color(hexString: member.colorHex))
                    .frame(width: 32, height: 32)
                Text(member.displayName.prefix(1))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(member.displayName)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                Text(member.role == .owner ? "Owner" : "Partner")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if isCurrent {
                Text("You")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.surface, in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(memberSummary))
    }

    private var memberSummary: String {
        var parts = [member.displayName, member.role == .owner ? "owner" : "partner"]
        if isCurrent { parts.append("this is you") }
        return parts.joined(separator: ", ")
    }
}

private struct PlaybookBankRowView: View {
    let account: DemoAccountsCatalog.DemoAccount
    let ownerName: String
    let ownerColorHex: String

    var body: some View {
        HStack(spacing: Theme.cardSpacing) {
            Image(systemName: "building.columns")
                .font(.subheadline)
                .foregroundStyle(Theme.primaryDark)
                .frame(width: 30, height: 30)
                .background(Theme.primaryTint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                if let mask = account.mask {
                    Text(verbatim: "••\(mask)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            PartnerBadge(name: ownerName, colorHex: ownerColorHex)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("\(account.displayName), belongs to \(ownerName)")
        )
    }
}

#Preview {
    PlaybookView()
        .environment(DemoSeed.makeRepositories())
}
