import SwiftUI
import TwoStepCore

/// Add/edit sheet for one recurring bill (PRD §4.6): merchant, amount,
/// frequency, next due date, category, attribution, account, and the
/// cash-only auto-log toggle. Editing an existing item adds the paused state.
struct RecurringItemFormSheet: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    /// nil = creating a new bill.
    private let existingItem: RecurringItem?

    @State private var merchant: String
    @State private var amountText: String
    @State private var frequency: RecurringItem.Frequency
    @State private var dueDate: Date
    @State private var categoryId: String?
    @State private var attribution: Attribution
    @State private var accountId: String?
    @State private var autoLog: Bool
    @State private var isPaused: Bool

    init(item: RecurringItem?, defaultDueDate: String) {
        existingItem = item
        _merchant = State(initialValue: item?.merchant ?? "")
        _amountText = State(initialValue: item.map { Self.editableAmount($0.amountMinor) } ?? "")
        _frequency = State(initialValue: item?.frequency ?? .monthly)
        _dueDate = State(initialValue: Self.date(from: item?.nextDueDate ?? defaultDueDate))
        _categoryId = State(initialValue: item?.categoryId)
        _attribution = State(initialValue: item?.attributedTo ?? .joint)
        _accountId = State(initialValue: item?.accountId ?? DemoSeed.jointCheckingId)
        _autoLog = State(initialValue: item?.autoLog ?? false)
        _isPaused = State(initialValue: item?.isPaused ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                billSection
                scheduleSection
                householdSection
                autoLogSection
                if existingItem != nil {
                    pausedSection
                }
            }
            .navigationTitle(existingItem == nil ? "New Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Sections

    private var billSection: some View {
        Section("Bill") {
            TextField("Merchant", text: $merchant)
            TextField("Amount", text: $amountText)
                .keyboardType(.decimalPad)
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Repeats", selection: $frequency) {
                ForEach(RecurringItem.Frequency.allCases, id: \.self) { frequency in
                    Text(Self.frequencyLabel(frequency)).tag(frequency)
                }
            }
            DatePicker("Next due", selection: $dueDate, displayedComponents: .date)
        }
    }

    private var householdSection: some View {
        Section("Household") {
            Picker("Category", selection: $categoryId) {
                Text("None").tag(String?.none)
                ForEach(selectableCategories) { category in
                    Text("\(category.emoji) \(category.name)").tag(String?.some(category.id))
                }
            }
            Picker("Paid by", selection: $attribution) {
                Text("Joint").tag(Attribution.joint)
                ForEach(repositories.households.members) { member in
                    Text(member.displayName).tag(Attribution.member(member.id))
                }
            }
            Picker("Account", selection: $accountId) {
                ForEach(DemoAccountsCatalog.accounts) { account in
                    Text(account.displayName).tag(String?.some(account.id))
                }
            }
        }
    }

    private var autoLogSection: some View {
        Section {
            Toggle("Auto-log on due date", isOn: $autoLog)
                .disabled(!isCashAccount)
        } footer: {
            Text(
                """
                Auto-log is available only for the Cash account. Bills on linked \
                accounts are predictive — the imported charge links to them \
                automatically, so nothing is counted twice.
                """
            )
        }
        .onChange(of: accountId) {
            if !isCashAccount { autoLog = false }
        }
    }

    private var pausedSection: some View {
        Section {
            Toggle("Paused", isOn: $isPaused)
        } footer: {
            Text("A paused bill keeps its history but leaves the forecast until you resume it.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .disabled(!isValid)
        }
    }

    // MARK: - Logic

    /// Income & Transfers never carry bills — they are excluded from budget
    /// movement entirely (PRD §4.4).
    private var selectableCategories: [TransactionCategory] {
        repositories.budgets.categories.filter {
            !repositories.budgets.excludedCategoryIds.contains($0.id)
        }
    }

    private var isCashAccount: Bool {
        DemoAccountsCatalog.account(withId: accountId)?.isCash == true
    }

    private var amountMinor: Int? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: normalized), decimal > 0 else { return nil }
        return Money(decimal: decimal).amountMinor
    }

    private var isValid: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountMinor != nil
    }

    private func save() {
        guard let amountMinor else { return }
        let item = RecurringItem(
            id: existingItem?.id ?? UUID().uuidString,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            amountMinor: amountMinor,
            frequency: frequency,
            nextDueDate: Self.dateString(from: dueDate),
            categoryId: categoryId,
            attributedTo: attribution,
            accountId: accountId,
            autoLog: autoLog && isCashAccount,
            isPaused: isPaused,
            endDate: existingItem?.endDate
        )
        if existingItem == nil {
            repositories.recurring.add(item)
        } else {
            repositories.recurring.update(item)
        }
        dismiss()
    }

    // MARK: - Helpers

    private static func frequencyLabel(_ frequency: RecurringItem.Frequency) -> LocalizedStringKey {
        switch frequency {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    /// "2200.00" — plain editable decimal text, no currency symbol.
    private static func editableAmount(_ amountMinor: Int) -> String {
        Money(amountMinor: amountMinor).decimalValue
            .formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    private static func date(from dateString: String) -> Date {
        guard let day = CalendarDay(dateString: dateString),
              let date = Calendar.current.date(
                  from: DateComponents(year: day.year, month: day.month, day: day.day)
              )
        else { return Date() }
        return date
    }

    private static func dateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 2026,
            components.month ?? 1,
            components.day ?? 1
        )
    }
}

#Preview {
    RecurringItemFormSheet(item: nil, defaultDueDate: DemoSeed.focusDate)
        .environment(DemoSeed.makeRepositories())
}
