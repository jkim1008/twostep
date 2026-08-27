import SwiftUI
import TwoStepCore

/// Savings tool (PRD §4.5 — priority hero). Opens on the combined-progress
/// hero across ALL active projects — total saved vs. total planned with each
/// partner's (and Joint's) share visible — then the project card grid,
/// duration-first creation, and an archived section that keeps history.
struct SavingsView: View {
    @Environment(AppRepositories.self) private var repositories
    @State private var archiveStore = SavingsArchiveStore()
    @State private var showNewProject = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: Theme.cardSpacing),
        GridItem(.flexible(), spacing: Theme.cardSpacing)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                if activeProjects.isEmpty {
                    emptyState
                } else {
                    hero
                    projectsSection
                }
                if !archivedProjects.isEmpty {
                    archivedSection
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, Theme.cardPadding * 4)
        }
        .background(Theme.background)
        .navigationTitle("Savings")
        .navigationDestination(for: SavingsProjectRoute.self) { route in
            SavingsProjectDetailView(projectId: route.projectId, archiveStore: archiveStore)
        }
        .sheet(isPresented: $showNewProject) {
            SavingsProjectFormSheet()
        }
    }

    // MARK: Derived state

    private var activeProjects: [SavingsProject] {
        repositories.savings.projects.filter { !archiveStore.isArchived($0) }
    }

    private var archivedProjects: [SavingsProject] {
        repositories.savings.projects.filter { archiveStore.isArchived($0) }
    }

    private var totalSavedMinor: Int {
        activeProjects.reduce(0) { $0 + $1.savedAmountMinor }
    }

    /// Total planned across active projects; an open-ended project counts at
    /// its saved amount so the combined fraction stays meaningful.
    private var totalPlannedMinor: Int {
        activeProjects.reduce(0) { $0 + ($1.targetAmountMinor ?? $1.savedAmountMinor) }
    }

    private var activeProjectIds: Set<String> {
        Set(activeProjects.map(\.id))
    }

    private var combinedShares: [SavingsShare] {
        let activeContributions = repositories.savings.contributions
            .filter { activeProjectIds.contains($0.projectId) }
        return SavingsShareMath.shares(
            contributions: activeContributions,
            households: repositories.households
        )
    }

    private func shares(for project: SavingsProject) -> [SavingsShare] {
        SavingsShareMath.shares(
            contributions: repositories.savings.contributions(forProject: project.id),
            households: repositories.households
        )
    }

    // MARK: Sections

    private var hero: some View {
        SavingsCombinedHeroView(
            totalSavedMinor: totalSavedMinor,
            totalPlannedMinor: totalPlannedMinor,
            projectCount: activeProjects.count,
            shares: combinedShares
        )
        .padding(.top, 4)
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Projects")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showNewProject = true
                } label: {
                    Label("New project", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .tint(Theme.primary)
            }
            LazyVGrid(columns: gridColumns, spacing: Theme.cardSpacing) {
                ForEach(activeProjects) { project in
                    NavigationLink(value: SavingsProjectRoute(projectId: project.id)) {
                        SavingsProjectCardView(project: project, shares: shares(for: project))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, Theme.cardSpacing)
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Archived")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            ForEach(archivedProjects) { project in
                NavigationLink(value: SavingsProjectRoute(projectId: project.id)) {
                    HStack(spacing: 8) {
                        Text(project.emoji)
                            .accessibilityHidden(true)
                        Text(project.name)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(SavingsFormat.compactCurrency(project.savedAmountMinor))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text("\(project.name), archived, saved \(SavingsFormat.currency(project.savedAmountMinor))")
                )
                Divider()
                    .overlay(Theme.separator)
            }
        }
        .padding(.top, Theme.cardSpacing)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "sparkles",
            title: "Start your first project",
            message: "Pick something you're saving for together — a trip, a couch, a rainy-day fund.",
            actionTitle: "New project",
            action: { showNewProject = true }
        )
        .padding(.top, Theme.cardPadding * 2)
    }
}

/// Typed navigation value for project drill-down — avoids colliding with any
/// other `String`-valued destination in the same stack.
struct SavingsProjectRoute: Hashable {
    let projectId: String
}

#Preview {
    NavigationStack {
        SavingsView()
    }
    .environment(DemoSeed.makeRepositories())
}
