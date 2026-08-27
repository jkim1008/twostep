import SwiftUI
import TwoStepCore

/// Project detail (PRD §4.5): large ring, plan line, contribution history
/// timeline with per-partner badges, add-contribution and archive actions,
/// and a completion celebration crediting both partners neutrally.
struct SavingsProjectDetailView: View {
    let projectId: String
    let archiveStore: SavingsArchiveStore

    @Environment(AppRepositories.self) private var repositories
    @State private var showContribute = false

    var body: some View {
        ScrollView {
            if let project {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    ringHero(project)
                    if (project.progressFraction ?? 0) >= 1 {
                        completionBanner(project)
                    }
                    actionButtons(project)
                    historySection(project)
                }
                .padding(.horizontal, Theme.cardPadding)
                .padding(.bottom, Theme.cardPadding * 2)
            } else {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "Project not found",
                    message: "This project is no longer available."
                )
            }
        }
        .background(Theme.background)
        .navigationTitle(project.map { "\($0.emoji) \($0.name)" } ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showContribute) {
            if let project {
                SavingsContributeSheet(
                    project: project,
                    defaultContributorId: repositories.households.currentMember?.id ?? DemoSeed.mayaUid
                )
            }
        }
    }

    // MARK: Live state

    private var project: SavingsProject? {
        repositories.savings.project(withId: projectId)
    }

    private var contributions: [Contribution] {
        repositories.savings.contributions(forProject: projectId)
    }

    private var shares: [SavingsShare] {
        SavingsShareMath.shares(contributions: contributions, households: repositories.households)
    }

    // MARK: Hero

    private func ringHero(_ project: SavingsProject) -> some View {
        VStack(spacing: 8) {
            SavingsRingView(fraction: project.progressFraction, lineWidth: 14) {
                VStack(spacing: 2) {
                    Text(SavingsFormat.compactCurrency(project.savedAmountMinor))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("saved")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: 180)
            .frame(maxWidth: .infinity)
            Text(targetLine(project))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            if let planLine = planLine(project) {
                Text(planLine)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.cardPadding)
        .accessibilityElement(children: .combine)
    }

    /// Both partners' totals, named neutrally — the acceptance criterion for
    /// the completion state (PRD §4.5).
    private func completionBanner(_ project: SavingsProject) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Funded — you did this together", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Theme.success)
            Text(completionSummary)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.success.opacity(0.13), in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }

    private func actionButtons(_ project: SavingsProject) -> some View {
        let isArchived = archiveStore.isArchived(project)
        return HStack(spacing: Theme.cardSpacing) {
            Button {
                showContribute = true
            } label: {
                Label("Add contribution", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .disabled(isArchived)
            Button {
                archiveStore.setArchived(!isArchived, projectId: project.id)
            } label: {
                Label(isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .tint(Theme.textSecondary)
        }
    }

    // MARK: History

    private func historySection(_ project: SavingsProject) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Contributions")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 8)
            if contributions.isEmpty {
                EmptyStateView(
                    systemImage: "plus.circle",
                    title: "No contributions yet",
                    message: "The first contribution starts the story.",
                    actionTitle: "Add contribution",
                    action: { showContribute = true }
                )
            } else {
                ForEach(contributions) { contribution in
                    SavingsContributionRow(contribution: contribution)
                        .contextMenu {
                            Button("Delete contribution", systemImage: "trash", role: .destructive) {
                                delete(contribution)
                            }
                        }
                    Divider()
                        .overlay(Theme.separator)
                }
            }
        }
    }

    private func delete(_ contribution: Contribution) {
        print("[SavingsProjectDetailView] Deleting contribution \(contribution.id)")
        repositories.savings.deleteContribution(withId: contribution.id)
    }

    // MARK: Lines

    private func targetLine(_ project: SavingsProject) -> String {
        guard let target = project.targetAmountMinor else { return "Open-ended project" }
        let remaining = max(0, target - project.savedAmountMinor)
        return remaining == 0
            ? "Target \(SavingsFormat.compactCurrency(target)) reached"
            : "of \(SavingsFormat.compactCurrency(target)) — \(SavingsFormat.compactCurrency(remaining)) to go"
    }

    private func planLine(_ project: SavingsProject) -> String? {
        guard project.recurringContributionMinor > 0, let months = project.durationMonths else { return nil }
        let amount = SavingsFormat.compactCurrency(project.recurringContributionMinor)
        return "Plan: \(amount)/month for \(months) months"
    }

    private var completionSummary: String {
        shares
            .filter { $0.amountMinor > 0 }
            .map { "\($0.name) contributed \(SavingsFormat.currency($0.amountMinor))" }
            .joined(separator: " · ")
    }
}

/// One timeline entry: amount, date, note, and the contributing partner's
/// badge (PRD §4.5 key UI).
private struct SavingsContributionRow: View {
    let contribution: Contribution

    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(SavingsFormat.currency(contribution.amountMinor))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text(SavingsFormat.shortDay(contribution.date))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                if let note = contribution.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            PartnerBadge(
                name: repositories.households.displayName(for: attribution),
                colorHex: repositories.households.badgeColorHex(for: attribution)
            )
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var attribution: Attribution {
        Attribution(rawValue: contribution.contributedByUid)
    }
}

#Preview {
    NavigationStack {
        SavingsProjectDetailView(projectId: "proj-anniversary-trip", archiveStore: SavingsArchiveStore())
    }
    .environment(DemoSeed.makeRepositories())
}
