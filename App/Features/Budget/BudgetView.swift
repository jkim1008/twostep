import SwiftUI
import TwoStepCore

/// Budget tool (PRD §4.4). Opens on the hero donut — category share of the
/// month's spend with the total centered — then the per-category list:
/// progress bars only where an allocation exists, plain spend + "Set budget"
/// elsewhere. Month navigation is free; only the current month's allocations
/// are editable.
struct BudgetView: View {
    @Environment(AppRepositories.self) private var repositories
    @State private var month = DemoSeed.focusMonth
    @State private var categoryStore = BudgetLocalCategoryStore()
    @State private var allocationTarget: BudgetCategoryItem?
    @State private var categoryFormMode: BudgetCategoryFormSheet.Mode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                BudgetMonthSwitcher(
                    month: $month,
                    earliestMonth: earliestMonth,
                    latestMonth: DemoSeed.focusMonth
                )
                donutHero
                categoryList
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, Theme.cardPadding * 4)
        }
        .background(Theme.background)
        .navigationTitle("Budget")
        .navigationDestination(for: BudgetCategoryItem.self) { item in
            BudgetCategoryDetailView(item: item, month: month, isEditable: isEditableMonth)
        }
        .sheet(item: $allocationTarget) { target in
            BudgetAllocationSheet(item: target, month: month)
        }
        .sheet(item: $categoryFormMode) { mode in
            BudgetCategoryFormSheet(
                mode: mode,
                month: month,
                isEditableMonth: isEditableMonth,
                store: categoryStore
            )
        }
    }

    // MARK: Derived state

    private var snapshot: BudgetMonthSnapshot {
        BudgetMonthSnapshot(
            month: month,
            categories: categoryStore.displayCategories(base: repositories.budgets.categories),
            excludedCategoryIds: repositories.budgets.excludedCategoryIds,
            allocations: repositories.budgets.budget(forMonth: month)?.allocations ?? [:],
            transactions: repositories.transactions.transactions
        )
    }

    /// Allocations are editable for the current month only (PRD §4.4:
    /// previous months' allocations are read-only; spend still recomputes).
    private var isEditableMonth: Bool {
        month == DemoSeed.focusMonth
    }

    private var earliestMonth: String {
        let budgetMin = repositories.budgets.budgetMonths.first?.month
        let transactionMin = repositories.transactions.transactions
            .compactMap { MonthKey.key(forDateString: $0.date) }
            .min()
        return [budgetMin, transactionMin].compactMap(\.self).min() ?? DemoSeed.focusMonth
    }

    // MARK: Hero

    @ViewBuilder
    private var donutHero: some View {
        let current = snapshot
        DonutChartView(segments: current.donutSegments) {
            VStack(spacing: 2) {
                HeroNumberView(amountMinor: current.totalDisplaySpentMinor)
                Text("spent")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.cardSpacing)
    }

    // MARK: Category list

    @ViewBuilder
    private var categoryList: some View {
        let current = snapshot
        if current.isEmpty {
            EmptyStateView(
                systemImage: "chart.pie",
                title: "No activity this month",
                message: "Spending lands here by category as transactions arrive.",
                actionTitle: isEditableMonth ? "New category" : nil,
                action: isEditableMonth ? { categoryFormMode = .create } : nil
            )
        } else {
            if !current.allocatedItems.isEmpty {
                section(titled: "Budgeted", items: current.allocatedItems)
            }
            if !current.unallocatedItems.isEmpty {
                section(titled: "Tracking only", items: current.unallocatedItems)
            }
            if !isEditableMonth {
                Text("Previous months' budgets are read-only — spend totals still update if transactions change.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 4)
            }
            newCategoryButton
        }
    }

    private func section(titled title: LocalizedStringKey, items: [BudgetCategoryItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 8)
            ForEach(items) { item in
                categoryRow(item)
                Divider()
                    .overlay(Theme.separator)
            }
        }
    }

    private func categoryRow(_ item: BudgetCategoryItem) -> some View {
        NavigationLink(value: item) {
            BudgetCategoryRowView(
                item: item,
                isEditable: isEditableMonth,
                onSetBudget: { allocationTarget = item }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isEditableMonth {
                Button("Set budget", systemImage: "slider.horizontal.3") {
                    allocationTarget = item
                }
            }
            if item.isCustom, let category = categoryStore.category(withId: item.id) {
                Button("Edit category", systemImage: "pencil") {
                    categoryFormMode = .edit(category)
                }
            }
        }
    }

    @ViewBuilder
    private var newCategoryButton: some View {
        if isEditableMonth {
            Button {
                categoryFormMode = .create
            } label: {
                Label("New category", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
            .padding(.top, 8)
        }
    }
}

/// Chevron month navigation. Bounds are inclusive; the demo's "today" month
/// is the latest — the future has no budget yet.
private struct BudgetMonthSwitcher: View {
    @Binding var month: String
    let earliestMonth: String
    let latestMonth: String

    var body: some View {
        HStack {
            Button {
                if let previous = MonthKey.previous(month) { month = previous }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .disabled(month <= earliestMonth)
            .accessibilityLabel(Text("Previous month"))
            Spacer()
            Text(BudgetFormat.monthTitle(month))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                if let next = MonthKey.next(month) { month = next }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(month >= latestMonth)
            .accessibilityLabel(Text("Next month"))
        }
        .tint(Theme.primary)
    }
}

#Preview {
    NavigationStack {
        BudgetView()
    }
    .environment(DemoSeed.makeRepositories())
}
