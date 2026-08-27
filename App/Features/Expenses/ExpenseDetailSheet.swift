import SwiftUI
import TwoStepCore

/// Detail/edit sheet for one transaction (PRD §4.3). Manual entries are
/// fully editable; imported ones expose only the user-owned fields —
/// category, attribution, notes, exclude, discuss flag, hide — while amount,
/// date, and merchant stay bank-truth. Imported rows are never hard-deleted
/// (re-sync would resurrect them); the symmetric household archive (hide)
/// is the designed alternative, and the demo's manual "delete" archives the
/// same way because the demo repository exposes no hard delete.
struct ExpenseDetailSheet: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    private let original: TwoStepCore.Transaction

    @State private var amountText: String
    @State private var date: Date
    @State private var merchant: String
    @State private var selectedCategoryId: String?
    @State private var attributionRaw: String
    @State private var notes: String
    @State private var excludeFromBudget: Bool
    @State private var flagToDiscuss: Bool
    @State private var discussNote: String
    @State private var confirmingDelete = false

    init(transaction: TwoStepCore.Transaction) {
        self.original = transaction
        _amountText = State(initialValue: Money(amountMinor: transaction.amountMinor)
            .decimalValue.formatted(.number.precision(.fractionLength(2)).grouping(.never)))
        _date = State(initialValue: ExpenseFormat.date(fromDateString: transaction.date) ?? Date())
        _merchant = State(initialValue: transaction.merchantName ?? "")
        _selectedCategoryId = State(initialValue: transaction.categoryId)
        _attributionRaw = State(initialValue: transaction.attributedTo.rawValue)
        _notes = State(initialValue: transaction.notes ?? "")
        _excludeFromBudget = State(initialValue: transaction.excludeFromBudget)
        _flagToDiscuss = State(initialValue: transaction.isAwaitingDiscussion)
        _discussNote = State(initialValue: transaction.discussNote ?? "")
    }

    private var isManual: Bool { original.source == .manual }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                categorySection
                attributionSection
                notesSection
                discussSection
                archiveSection
            }
            .navigationTitle(isManual ? "Edit entry" : "Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    // MARK: Sections

    /// Manual: editable amount/date/merchant. Imported: bank-truth, read-only.
    @ViewBuilder private var basicsSection: some View {
        if isManual {
            Section("Amount & date") {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Merchant", text: $merchant)
            }
        } else {
            Section {
                LabeledContent("Amount") {
                    Text(verbatim: ExpenseFormat.money(original.amountMinor)).monospacedDigit()
                }
                LabeledContent("Date") {
                    Text(verbatim: ExpenseFormat.dayHeader(original.date, today: DemoSeed.focusDate))
                }
                LabeledContent("Merchant") {
                    Text(verbatim: original.merchantName ?? "—")
                }
                if original.status == .pending {
                    LabeledContent("Status") { Text("Pending") }
                }
            } footer: {
                Text("Imported amounts, dates, and merchants stay as the bank reported them.")
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            ExpenseCategoryGridView(
                categories: repositories.budgets.categories.filter { !$0.isArchived },
                selectedCategoryId: $selectedCategoryId
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private var attributionSection: some View {
        Section("Attributed to") {
            Picker("Attributed to", selection: $attributionRaw) {
                ForEach(repositories.households.members) { member in
                    Text(verbatim: member.displayName).tag(member.id)
                }
                Text("Joint").tag(Attribution.joint.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add a note", text: $notes, axis: .vertical)
            Toggle("Exclude from budget", isOn: $excludeFromBudget)
        }
    }

    private var discussSection: some View {
        Section {
            Toggle("Let's discuss", isOn: $flagToDiscuss)
            if flagToDiscuss {
                TextField("What's the question?", text: $discussNote, axis: .vertical)
            }
        } footer: {
            Text("Flags surface in the Weekly Sync — no alerts, no urgency.")
        }
    }

    private var archiveSection: some View {
        Section {
            if isManual {
                Button("Delete entry", role: .destructive) { confirmingDelete = true }
                    .confirmationDialog(
                        "Delete this entry?",
                        isPresented: $confirmingDelete,
                        titleVisibility: .visible
                    ) {
                        Button("Delete entry", role: .destructive) { archive() }
                    }
            } else if original.isHidden {
                Button("Unhide transaction") { unhide() }
            } else {
                Button("Hide transaction", role: .destructive) { archive() }
            }
        } footer: {
            if !isManual {
                Text("Hiding archives this for both partners — it stays under the Hidden filter and either of you can unhide it.")
            }
        }
    }

    // MARK: Actions

    private func save() {
        var updated = original
        if isManual {
            if let amountMinor = parsedAmountMinor { updated.amountMinor = amountMinor }
            updated.date = ExpenseFormat.dateString(from: date)
            let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.merchantName = trimmedMerchant.isEmpty ? nil : trimmedMerchant
        }
        if updated.categoryId != selectedCategoryId {
            updated.categoryId = selectedCategoryId
            // Guards re-sync from clobbering a user's recategorization.
            if original.source == .plaid { updated.categoryOverriddenByUser = true }
        }
        updated.attributedTo = Attribution(rawValue: attributionRaw)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        updated.excludeFromBudget = excludeFromBudget
        applyDiscussFlag(to: &updated)
        repositories.transactions.update(updated)
        dismiss()
    }

    private func applyDiscussFlag(to updated: inout TwoStepCore.Transaction) {
        let trimmedDiscussNote = discussNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if flagToDiscuss {
            updated.discussFlaggedByUid = original.discussFlaggedByUid
                ?? repositories.households.currentMember?.id
            updated.discussNote = trimmedDiscussNote.isEmpty ? nil : trimmedDiscussNote
            updated.discussResolvedAt = nil
        } else if original.isAwaitingDiscussion {
            // Either partner can resolve a flag (PRD §4.7.2).
            updated.discussResolvedAt = Date()
        }
    }

    /// Symmetric household archive — records who hid it (PRD §4.3).
    private func archive() {
        var updated = original
        updated.isHidden = true
        updated.hiddenByUid = repositories.households.currentMember?.id
        repositories.transactions.update(updated)
        dismiss()
    }

    private func unhide() {
        var updated = original
        updated.isHidden = false
        updated.hiddenByUid = nil
        repositories.transactions.update(updated)
        dismiss()
    }

    /// Decimal text → minor units via `Money`'s canonical rounding; nil for
    /// unparseable or non-positive input (the original amount then stands).
    private var parsedAmountMinor: Int? {
        let normalized = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: normalized), decimal > 0 else { return nil }
        return Money(decimal: decimal).amountMinor
    }
}

#Preview {
    let repositories = DemoSeed.makeRepositories()
    return ExpenseDetailSheet(transaction: repositories.transactions.transactions[0])
        .environment(repositories)
}
