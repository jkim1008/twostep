import SwiftUI
import TwoStepCore

/// The Alert Center (PRD §4.9): the household activity feed behind the header
/// bell — the ambient answer to "what happened while I wasn't looking?".
/// Opening advances the viewer's seen-marker in the event repository (the
/// same store the shell's bell badge reads), on this device only.
struct AlertCenterView: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    /// Rows that were unread at the moment the sheet opened keep their "New"
    /// tag for this viewing, even though opening already advanced the cursor.
    @State private var newRowCount = 0
    @State private var hasMarkedSeen = false

    var body: some View {
        NavigationStack {
            content
                .background(Theme.background)
                .navigationTitle("Alert Center")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneButton }
                .onAppear(perform: markSeenOnce)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var content: some View {
        let events = repositories.events.events
        if events.isEmpty {
            EmptyStateView(
                systemImage: "bell",
                title: "All quiet",
                message: "Household activity — expenses, contributions, budget edits — shows up here."
            )
        } else {
            List(Array(events.enumerated()), id: \.element.id) { index, event in
                AlertCenterRowView(
                    event: event,
                    actor: repositories.households.member(withId: event.actorUid),
                    isNew: index < newRowCount
                )
                .listRowBackground(Theme.background)
                .listRowSeparatorTint(Theme.separator)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    /// Captures the unread count for "New" tags, then advances the viewer's
    /// cursor — the shell bell badge clears from the same store (PRD §4.9:
    /// per-device, never the partner's).
    private func markSeenOnce() {
        guard !hasMarkedSeen else { return }
        hasMarkedSeen = true
        newRowCount = repositories.events.unreadCount
        repositories.events.markAllSeen()
    }
}

/// One feed row: event icon, the neutral payload summary, the actor's partner
/// badge, and a relative timestamp. Rows are a household log, not a
/// partner-watching tool — the viewer's own actions appear too.
private struct AlertCenterRowView: View {
    let event: HouseholdEvent
    let actor: HouseholdMember?
    let isNew: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.cardSpacing) {
            icon
            details
            Spacer(minLength: 8)
            if isNew {
                newTag
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    // MARK: - Pieces

    private var icon: some View {
        Image(systemName: symbolName)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.primaryDark)
            .frame(width: 34, height: 34)
            .background(Theme.primaryTint, in: Circle())
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.payload)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if let actor {
                    PartnerBadge(name: actor.displayName, colorHex: actor.colorHex)
                }
                Text(event.timestamp, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var newTag: some View {
        Text("New")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.primaryDark)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.primaryTint, in: Capsule())
    }

    private var symbolName: String {
        switch event.type {
        case .memberJoined: "person.badge.plus"
        case .memberLeft: "person.badge.minus"
        case .expenseAdded: "plus.circle"
        case .expenseEdited: "pencil.circle"
        case .budgetChanged: "chart.pie"
        case .accountLinked: "building.columns"
        case .accountUnlinked: "building.columns.circle"
        case .projectCreated: "sparkles"
        case .contributionAdded: "arrow.up.circle"
        }
    }

    private var accessibilitySummary: String {
        var parts = [event.payload]
        if isNew { parts.insert("New", at: 0) }
        parts.append(
            event.timestamp.formatted(.relative(presentation: .named))
        )
        return parts.joined(separator: ", ")
    }
}

#Preview {
    AlertCenterView()
        .environment(DemoSeed.makeRepositories())
}
