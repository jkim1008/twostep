import SwiftUI
import TwoStepCore

/// Create or edit a custom category: name, emoji identity (PRD §6.3), and an
/// optional allocation for the current month. System categories are managed
/// through their allocation sheet only; this form owns the custom ones.
struct BudgetCategoryFormSheet: View {
    enum Mode: Identifiable {
        case create
        case edit(TransactionCategory)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let category): category.id
            }
        }
    }

    let mode: Mode
    let month: String
    /// Allocation editing is only offered for the editable (current) month.
    let isEditableMonth: Bool
    let store: BudgetLocalCategoryStore

    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var allocationText: String

    private static let emojiChoices = [
        "🏷️", "🎁", "🐶", "✈️", "👶", "🎓", "💻", "🎮",
        "🧵", "🌿", "☕️", "🎨", "📚", "🚲", "🧴", "🏕️"
    ]

    init(mode: Mode, month: String, isEditableMonth: Bool, store: BudgetLocalCategoryStore) {
        self.mode = mode
        self.month = month
        self.isEditableMonth = isEditableMonth
        self.store = store
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _emoji = State(initialValue: Self.emojiChoices[0])
        case .edit(let category):
            _name = State(initialValue: category.name)
            _emoji = State(initialValue: category.emoji)
        }
        _allocationText = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                if isEditableMonth {
                    allocationSection
                }
                if case .edit(let category) = mode {
                    archiveSection(category)
                }
            }
            .navigationTitle(isCreating ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section("Name & emoji") {
            TextField("Category name", text: $name)
            BudgetEmojiPickerGrid(choices: Self.emojiChoices, selection: $emoji)
        }
    }

    private var allocationSection: some View {
        Section {
            HStack {
                Text("Monthly budget")
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                TextField("Optional", text: $allocationText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .accessibilityLabel(Text("Optional monthly budget amount in dollars"))
            }
        } footer: {
            Text("Leave empty to track spend without a budget.")
        }
    }

    private func archiveSection(_ category: TransactionCategory) -> some View {
        Section {
            Button(role: .destructive) {
                archive(category)
            } label: {
                Text("Archive category")
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
        } footer: {
            Text("Archived categories keep their history but leave the pickers.")
        }
    }

    // MARK: Actions

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private func save() {
        switch mode {
        case .create:
            let category = store.add(name: trimmedName, emoji: emoji)
            print("[BudgetCategoryFormSheet] Created category \(category.id) (\(trimmedName))")
            if isEditableMonth, let minor = BudgetFormat.minorUnits(fromInput: allocationText), minor > 0 {
                repositories.budgets.setAllocation(minor, forCategory: category.id, inMonth: month)
            }
        case .edit(let category):
            store.update(id: category.id, name: trimmedName, emoji: emoji)
            print("[BudgetCategoryFormSheet] Updated category \(category.id) (\(trimmedName))")
            if isEditableMonth, let minor = BudgetFormat.minorUnits(fromInput: allocationText), minor > 0 {
                repositories.budgets.setAllocation(minor, forCategory: category.id, inMonth: month)
            }
        }
        dismiss()
    }

    private func archive(_ category: TransactionCategory) {
        store.archive(id: category.id)
        // A dead category should not keep a live allocation this month.
        repositories.budgets.setAllocation(nil, forCategory: category.id, inMonth: month)
        print("[BudgetCategoryFormSheet] Archived category \(category.id)")
        dismiss()
    }
}

/// 44pt emoji swatches; the selection is highlighted with a tint *and* a
/// border so state never rides on color alone.
private struct BudgetEmojiPickerGrid: View {
    let choices: [String]
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.adaptive(minimum: 44), spacing: 8), count: 1)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(choices, id: \.self) { choice in
                Button {
                    selection = choice
                } label: {
                    Text(choice)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(
                            choice == selection ? Theme.primaryTint : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    choice == selection ? Theme.primary : .clear,
                                    lineWidth: 2
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Emoji \(choice)"))
                .accessibilityAddTraits(choice == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BudgetCategoryFormSheet(
        mode: .create,
        month: DemoSeed.focusMonth,
        isEditableMonth: true,
        store: BudgetLocalCategoryStore()
    )
    .environment(DemoSeed.makeRepositories())
}
