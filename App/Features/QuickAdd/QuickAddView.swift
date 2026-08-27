import SwiftUI
import TwoStepCore

/// Quick Add (PRD §4.3): dial-pad amount entry, emoji-first category grid,
/// attribution defaulting to the entry author (manual-entry precedence —
/// the Cash account's nil owner never forces Joint), plus optional merchant,
/// date, and note. Saving writes through the shared transaction repository,
/// so the entry lands on the feed, Dashboard, and Budget instantly.
struct QuickAddView: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @State private var amountMinor = 0
    @State private var selectedCategoryId: String?
    @State private var attributionRaw = ""
    @State private var merchant = ""
    @State private var note = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    amountDisplay
                    QuickAddDialPad(amountMinor: $amountMinor)
                    sectionHeader("Category")
                    QuickAddCategoryGrid(
                        categories: spendingCategories,
                        selectedCategoryId: $selectedCategoryId
                    )
                    sectionHeader("Attributed to")
                    attributionPicker
                    detailsSection
                    saveButton
                }
                .padding(Theme.cardPadding)
            }
            .background(Theme.background)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: seedDefaults)
        }
    }

    // MARK: Pieces

    private var amountDisplay: some View {
        VStack(spacing: 2) {
            Text(verbatim: formattedAmount)
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(amountMinor == 0 ? Theme.textTertiary : Theme.textPrimary)
                .contentTransition(.numericText(value: Double(amountMinor)))
                .animation(.easeOut(duration: 0.15), value: amountMinor)
            Text("Amount")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Amount \(formattedAmount)"))
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private var attributionPicker: some View {
        Picker("Attributed to", selection: $attributionRaw) {
            ForEach(repositories.households.members) { member in
                Text(verbatim: member.displayName).tag(member.id)
            }
            Text("Joint").tag(Attribution.joint.rawValue)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var detailsSection: some View {
        VStack(spacing: 0) {
            TextField("Merchant (optional)", text: $merchant)
                .padding(Theme.cardPadding)
            Divider().overlay(Theme.separator)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .padding(.horizontal, Theme.cardPadding)
                .padding(.vertical, 8)
            Divider().overlay(Theme.separator)
            TextField("Note (optional)", text: $note)
                .padding(Theme.cardPadding)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Add expense")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    canSave ? Theme.primary : Theme.textTertiary,
                    in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                )
        }
        .disabled(!canSave)
        .accessibilityHint(canSave
            ? Text("Saves the expense to the shared feed")
            : Text("Enter an amount and pick a category first"))
    }

    // MARK: Data

    /// Spending categories only — Income & Transfers are excluded from a
    /// fast expense keypad.
    private var spendingCategories: [TransactionCategory] {
        repositories.budgets.categories.filter {
            !$0.isArchived && !repositories.budgets.excludedCategoryIds.contains($0.id)
        }
    }

    private var canSave: Bool {
        amountMinor > 0 && selectedCategoryId != nil
    }

    private var formattedAmount: String {
        Money(amountMinor: amountMinor).decimalValue.formatted(.currency(code: "USD"))
    }

    /// Author defaults (PRD §4.3): attribution starts as the entry author;
    /// the date starts on the demo's pinned today.
    private func seedDefaults() {
        if attributionRaw.isEmpty {
            attributionRaw = repositories.households.currentMember?.id ?? Attribution.joint.rawValue
        }
        if let today = QuickAddDates.date(fromDateString: DemoSeed.focusDate) {
            date = today
        }
    }

    /// Manual entry to the built-in Cash account (PRD §4.3 flow 3). Cash
    /// entries are exempt from dedup matching, and the author-attribution
    /// precedence means the nil-owner Cash account never forces Joint.
    private func save() {
        guard canSave else { return }
        let transaction = Transaction(
            id: "manual-\(UUID().uuidString)",
            source: .manual,
            accountId: DemoSeed.cashAccountId,
            amountMinor: amountMinor,
            direction: .expense,
            date: QuickAddDates.dateString(from: date),
            merchantName: trimmedOrNil(merchant),
            categoryId: selectedCategoryId,
            attributedTo: Attribution(rawValue: attributionRaw),
            enteredByUid: repositories.households.currentMember?.id,
            status: .posted,
            notes: trimmedOrNil(note)
        )
        repositories.transactions.add(transaction)
        dismiss()
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// `Date` ↔ canonical `"YYYY-MM-DD"` bridging for the date picker.
private enum QuickAddDates {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func date(fromDateString dateString: String) -> Date? {
        formatter.date(from: dateString)
    }

    static func dateString(from date: Date) -> String {
        formatter.string(from: date)
    }
}

#Preview {
    QuickAddView()
        .environment(DemoSeed.makeRepositories())
}
