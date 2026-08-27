import SwiftUI
import TwoStepCore

/// Set / edit / remove one category's allocation for one month (PRD §4.4).
/// Only ever presented for the editable (current) month — callers gate on
/// the read-only rule for past months.
struct BudgetAllocationSheet: View {
    let item: BudgetCategoryItem
    let month: String

    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    init(item: BudgetCategoryItem, month: String) {
        self.item = item
        self.month = month
        _amountText = State(initialValue: item.allocationMinor.map(BudgetFormat.editableAmount) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(item.emoji)
                            .accessibilityHidden(true)
                        Text(item.name)
                            .font(.headline)
                    }
                    HStack {
                        Text("Monthly budget")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .accessibilityLabel(Text("Monthly budget amount in dollars"))
                    }
                } footer: {
                    Text(
                        "Applies to \(BudgetFormat.monthTitle(month)). Spend is tracked either way — a budget just adds the progress bar."
                    )
                }

                if item.allocationMinor != nil {
                    Section {
                        Button(role: .destructive) {
                            removeAllocation()
                        } label: {
                            Text("Remove budget")
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                    }
                }
            }
            .navigationTitle("Set budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(parsedMinor == nil || parsedMinor == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var parsedMinor: Int? {
        BudgetFormat.minorUnits(fromInput: amountText)
    }

    private func save() {
        guard let minor = parsedMinor, minor > 0 else { return }
        print("[BudgetAllocationSheet] Set \(item.name) to \(minor) minor units for \(month)")
        repositories.budgets.setAllocation(minor, forCategory: item.id, inMonth: month)
        appendEvent(summary: "set \(item.emoji) \(item.name) to \(BudgetFormat.compactCurrency(minor))")
        dismiss()
    }

    private func removeAllocation() {
        print("[BudgetAllocationSheet] Removed \(item.name) allocation for \(month)")
        repositories.budgets.setAllocation(nil, forCategory: item.id, inMonth: month)
        appendEvent(summary: "removed the \(item.emoji) \(item.name) budget")
        dismiss()
    }

    private func appendEvent(summary: String) {
        guard let member = repositories.households.currentMember else { return }
        repositories.events.append(HouseholdEvent(
            id: UUID().uuidString,
            type: .budgetChanged,
            actorUid: member.id,
            timestamp: DemoSeed.timestamp(DemoSeed.focusDate, hour: 18),
            payload: "\(member.displayName) \(summary)"
        ))
    }
}

#Preview {
    BudgetAllocationSheet(
        item: BudgetCategoryItem(
            id: "groceries", name: "Groceries", emoji: "🛒", colorHex: "#F97316",
            isCustom: false, trueSpentMinor: 512_40, allocationMinor: 650_00
        ),
        month: DemoSeed.focusMonth
    )
    .environment(DemoSeed.makeRepositories())
}
