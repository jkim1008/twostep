import SwiftUI
import TwoStepCore

/// Savings snapshot row (PRD §4.8): combined progress across all active
/// projects. Navigates into the Savings tool. The fill is always sage — a
/// full savings bar is a win, so budget threshold colors never apply here.
struct DashboardSavingsRow: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        NavigationLink {
            SavingsView()
        } label: {
            DashboardCard(title: "Savings") {
                if projects.isEmpty {
                    Text("No projects yet — start one in the Savings tab.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    snapshot
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens the Savings tool"))
    }

    private var snapshot: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: projects.map(\.emoji).joined(separator: " "))
                    .font(.subheadline)
                    .accessibilityHidden(true)
                Text("^[\(projects.count) project](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(verbatim: savedLabel)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            if totalTargetMinor > 0 {
                savingsBar
            }
        }
    }

    /// Plain sage fill — deliberately not `ProgressBarView`, whose amber/red
    /// thresholds mean "overspending" (backwards for savings progress).
    private var savingsBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.background)
                Capsule()
                    .fill(Theme.primary)
                    .frame(width: geometry.size.width * savedFraction)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(Text("\(Int((savedFraction * 100).rounded())) percent of combined savings targets reached"))
    }

    // MARK: Math (aggregates of core-maintained project fields)

    private var projects: [SavingsProject] {
        repositories.savings.projects.filter { !$0.isArchived }
    }

    private var totalSavedMinor: Int {
        projects.reduce(0) { $0 + $1.savedAmountMinor }
    }

    /// Sum of resolved targets (manual-first, then derived — `SavingsProject`
    /// owns that rule). Open-ended projects contribute no target.
    private var totalTargetMinor: Int {
        projects.reduce(0) { $0 + ($1.targetAmountMinor ?? 0) }
    }

    private var savedFraction: Double {
        guard totalTargetMinor > 0 else { return 0 }
        return min(1.0, Double(totalSavedMinor) / Double(totalTargetMinor))
    }

    private var savedLabel: String {
        let saved = DashboardFormat.money(totalSavedMinor)
        guard totalTargetMinor > 0 else { return saved }
        return "\(saved) of \(DashboardFormat.money(totalTargetMinor))"
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DashboardSavingsRow()
                .padding()
        }
        .background(Theme.background)
    }
    .environment(DemoSeed.makeRepositories())
}
