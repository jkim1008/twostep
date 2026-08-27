import SwiftUI
import TwoStepCore

/// The Recurring tab (PRD §4.6): the calendar IS the hero — the tab opens
/// directly on the grid with payment chips, nothing stacked above it. The
/// Day/Week/Month toggle rescopes the grid and the agenda beneath together;
/// both always cover the identical visible period.
struct RecurringView: View {
    @Environment(AppRepositories.self) private var repositories

    @State private var scope: RecurringCalendarScope = .month
    @State private var anchor = Self.demoToday
    @State private var editingItem: RecurringItem?
    @State private var isAddingItem = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                calendarHero
                RecurringAgendaView(
                    occurrences: visibleOccurrences,
                    displayName: repositories.households.displayName(for:),
                    badgeColorHex: repositories.households.badgeColorHex(for:),
                    onSelect: { occurrence in
                        editingItem = repositories.recurring.item(withId: occurrence.itemId)
                    },
                    onAdd: { isAddingItem = true }
                )
                .padding(.top, Theme.cardSpacing)
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, Theme.cardPadding * 5)
        }
        .background(Theme.background)
        .navigationTitle("Recurring")
        .toolbar { addButton }
        .sheet(isPresented: $isAddingItem) {
            RecurringItemFormSheet(item: nil, defaultDueDate: anchor.dateString)
        }
        .sheet(item: $editingItem) { item in
            RecurringItemFormSheet(item: item, defaultDueDate: item.nextDueDate)
        }
    }

    // MARK: - Calendar hero

    private var calendarHero: some View {
        VStack(spacing: Theme.cardSpacing) {
            periodHeader
            Picker("Calendar scope", selection: $scope) {
                Text("Day").tag(RecurringCalendarScope.day)
                Text("Week").tag(RecurringCalendarScope.week)
                Text("Month").tag(RecurringCalendarScope.month)
            }
            .pickerStyle(.segmented)
            RecurringCalendarGridView(
                scope: scope,
                anchor: anchor,
                today: Self.demoToday,
                occurrencesByDate: RecurringCalendarModel.occurrencesByDate(visibleOccurrences),
                badgeColorHex: repositories.households.badgeColorHex(for:),
                onSelectDay: { day in
                    anchor = day
                    scope = .day
                }
            )
        }
    }

    private var periodHeader: some View {
        HStack {
            periodChevron(systemImage: "chevron.left", label: "Previous period", steps: -1)
            Spacer()
            Text(periodTitle)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            periodChevron(systemImage: "chevron.right", label: "Next period", steps: 1)
        }
    }

    private func periodChevron(systemImage: String, label: LocalizedStringKey, steps: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                anchor = RecurringCalendarModel.advance(anchor, by: scope, steps: steps)
            }
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.primaryDark)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(Text(label))
    }

    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isAddingItem = true
            } label: {
                Image(systemName: "plus")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("Add a recurring bill"))
        }
    }

    // MARK: - Data

    private var visibleOccurrences: [BillOccurrence] {
        let (start, end) = RecurringCalendarModel.period(for: scope, anchor: anchor)
        return RecurringCalendarModel.occurrences(
            items: repositories.recurring.items,
            transactions: repositories.transactions.transactions,
            from: start,
            to: end
        )
    }

    private var periodTitle: String {
        switch scope {
        case .day:
            return DemoDayText.weekdayShortDate(anchor.dateString)
        case .week:
            let (start, end) = RecurringCalendarModel.period(for: .week, anchor: anchor)
            return DemoDayText.range(start.dateString, end.dateString)
        case .month:
            return DemoDayText.monthYear(of: anchor)
        }
    }

    /// The pinned demo "today" (see `DemoSeed`); falls back to day zero only
    /// if the seed constant were ever malformed.
    private static var demoToday: CalendarDay {
        CalendarDay(dateString: DemoSeed.focusDate) ?? CalendarDay(dayNumber: 0)
    }
}

#Preview {
    NavigationStack {
        RecurringView()
    }
    .environment(DemoSeed.makeRepositories())
}
