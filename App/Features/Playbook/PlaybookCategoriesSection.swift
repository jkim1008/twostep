import SwiftUI
import TwoStepCore

/// Categories & allocations at a glance (PRD §4.10): every category with its
/// emoji, name, and current-month allocation — mirroring the Budget tool's
/// state exactly, because both read the same repository.
struct PlaybookCategoriesSection: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        Section {
            ForEach(repositories.budgets.categories) { category in
                row(for: category)
            }
        } header: {
            Text("Categories & allocations")
        } footer: {
            Text("Budgeting is opt-in per category — categories without an allocation still track spending.")
        }
    }

    // MARK: - Pieces

    private func row(for category: TransactionCategory) -> some View {
        HStack(spacing: 8) {
            Text(category.emoji)
                .accessibilityHidden(true)
            Text(category.name)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            trailingText(for: category)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary(for: category)))
    }

    @ViewBuilder
    private func trailingText(for category: TransactionCategory) -> some View {
        if repositories.budgets.excludedCategoryIds.contains(category.id) {
            Text("Excluded from budget")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        } else if let allocation = currentAllocations[category.id] {
            Text(DemoDayText.currency(allocation))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        } else {
            Text("No allocation")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Derived

    private var currentAllocations: [String: Int] {
        repositories.budgets.budget(forMonth: DemoSeed.focusMonth)?.allocations ?? [:]
    }

    private func summary(for category: TransactionCategory) -> String {
        if repositories.budgets.excludedCategoryIds.contains(category.id) {
            return "\(category.name), excluded from budget"
        }
        if let allocation = currentAllocations[category.id] {
            return "\(category.name), allocated \(DemoDayText.currency(allocation)) this month"
        }
        return "\(category.name), no allocation this month"
    }
}

#Preview {
    List {
        PlaybookCategoriesSection()
    }
    .environment(DemoSeed.makeRepositories())
}
