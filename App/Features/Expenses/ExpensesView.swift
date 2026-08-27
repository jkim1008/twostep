import SwiftUI
import TwoStepCore

/// Expenses (PRD §4.3): the household's one merged, searchable feed. Opens
/// with the live total-spent hero (day/month toggle, same tested spend
/// formula as Budget/Dashboard — `HeroNumberView` animates the count-up as
/// entries land); the feed sits beneath, grouped by day, with search, a
/// calendar date-range filter, and the Hidden archive filter.
struct ExpensesView: View {
    @Environment(AppRepositories.self) private var repositories

    @State private var searchText = ""
    @State private var scope: SpendScope = .month
    @State private var filter = ExpenseFeedFilter()
    @State private var showFilterSheet = false
    @State private var selectedTransaction: TwoStepCore.Transaction?

    private let month = DemoSeed.focusMonth
    private let today = DemoSeed.focusDate

    var body: some View {
        List {
            heroSection
            feedSections
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Expenses")
        .searchable(text: $searchText, prompt: Text("Search merchants, notes, categories"))
        .toolbar { filterToolbarItem }
        .sheet(isPresented: $showFilterSheet) { ExpensesFilterSheet(filter: $filter) }
        .sheet(item: $selectedTransaction) { transaction in
            ExpenseDetailSheet(transaction: transaction)
        }
    }

    // MARK: Hero (DESIGN.md §5.4 — first thing on screen, nothing above it)

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HeroNumberView(amountMinor: heroAmountMinor)
                    .accessibilityIdentifier("expenses.hero")
                Text(scope == .day ? "Spent today" : "Spent this month")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Picker("Total spent scope", selection: $scope) {
                    Text("Day").tag(SpendScope.day)
                    Text("Month").tag(SpendScope.month)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            .padding(.vertical, 4)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// Live total for the selected scope — `BudgetMath.totalSpent`, the same
    /// tested spend formula as §4.4 (non-excluded, non-hidden, direction
    /// netting), floored at 0 for display.
    private var heroAmountMinor: Int {
        let scoped = switch scope {
        case .month: repositories.transactions.transactions
        case .day: repositories.transactions.transactions.filter { $0.date == today }
        }
        return BudgetMath.displaySpent(BudgetMath.totalSpent(transactions: scoped, month: month))
    }

    // MARK: Feed

    @ViewBuilder private var feedSections: some View {
        if daySections.isEmpty {
            Section {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matching transactions",
                    message: "Try a different search or clear the date-range filter."
                )
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            ForEach(daySections) { section in
                Section {
                    ForEach(section.transactions) { transaction in
                        feedRow(transaction)
                    }
                } header: {
                    Text(verbatim: ExpenseFormat.dayHeader(section.date, today: today))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(nil)
                }
            }
        }
    }

    private func feedRow(_ transaction: TwoStepCore.Transaction) -> some View {
        Button {
            selectedTransaction = transaction
        } label: {
            ExpenseRowView(transaction: transaction)
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.background)
        .accessibilityHint(Text("Opens the transaction details"))
    }

    /// Reverse-chronological feed (repository order) grouped by calendar day,
    /// after the hidden/date-range/search filters.
    private var daySections: [ExpenseDaySection] {
        let visible = repositories.transactions.transactions.filter { transaction in
            (filter.showHidden || !transaction.isHidden)
                && filter.containsDate(transaction.date)
                && matchesSearch(transaction)
        }
        let grouped = Dictionary(grouping: visible, by: \.date)
        return grouped.keys.sorted(by: >).map { date in
            ExpenseDaySection(date: date, transactions: grouped[date] ?? [])
        }
    }

    private func matchesSearch(_ transaction: TwoStepCore.Transaction) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        var haystack = [transaction.merchantName, transaction.notes, transaction.originalDescription]
        if let categoryId = transaction.categoryId,
           let category = repositories.budgets.category(withId: categoryId) {
            haystack.append(category.name)
        }
        return haystack.contains { $0?.localizedCaseInsensitiveContains(query) == true }
    }

    private var filterToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: filter.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(filter.isActive ? "Change filters, filters active" : "Filter the feed")
        }
    }

    private enum SpendScope: Hashable {
        case day
        case month
    }
}

#Preview {
    NavigationStack {
        ExpensesView()
    }
    .environment(DemoSeed.makeRepositories())
}
