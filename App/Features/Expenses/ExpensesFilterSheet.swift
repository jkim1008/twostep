import SwiftUI

/// Calendar date-range filter for the feed (PRD §4.3), plus the Hidden
/// filter that surfaces the symmetric household archive.
struct ExpensesFilterSheet: View {
    @Binding var filter: ExpenseFeedFilter
    @Environment(\.dismiss) private var dismiss

    @State private var limitToRange: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showHidden: Bool

    init(filter: Binding<ExpenseFeedFilter>) {
        _filter = filter
        let current = filter.wrappedValue
        let fallbackEnd = ExpenseFormat.date(fromDateString: DemoSeed.focusDate) ?? Date()
        let fallbackStart = ExpenseFormat.date(fromDateString: "\(DemoSeed.focusMonth)-01") ?? fallbackEnd
        _limitToRange = State(initialValue: current.startDate != nil || current.endDate != nil)
        _startDate = State(initialValue: current.startDate.flatMap(ExpenseFormat.date(fromDateString:)) ?? fallbackStart)
        _endDate = State(initialValue: current.endDate.flatMap(ExpenseFormat.date(fromDateString:)) ?? fallbackEnd)
        _showHidden = State(initialValue: current.showHidden)
    }

    var body: some View {
        NavigationStack {
            Form {
                rangeSection
                Section {
                    Toggle("Show hidden", isOn: $showHidden)
                } footer: {
                    Text("Hidden transactions are the shared archive — visible to both partners, never one-sided.")
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { reset() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var rangeSection: some View {
        Section("Date range") {
            Toggle("Limit to a date range", isOn: $limitToRange.animation())
            if limitToRange {
                DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
        }
    }

    private func apply() {
        filter = ExpenseFeedFilter(
            startDate: limitToRange ? ExpenseFormat.dateString(from: startDate) : nil,
            endDate: limitToRange ? ExpenseFormat.dateString(from: endDate) : nil,
            showHidden: showHidden
        )
        dismiss()
    }

    private func reset() {
        filter = ExpenseFeedFilter()
        dismiss()
    }
}

#Preview {
    ExpensesFilterSheet(filter: .constant(ExpenseFeedFilter()))
        .environment(DemoSeed.makeRepositories())
}
