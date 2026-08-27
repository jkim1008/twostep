import SwiftUI
import TwoStepCore

/// Emoji-first category picker grid (PRD §4.3 detail sheet). Emoji is the
/// category's primary identity but is always paired with the name; selection
/// is carried by a border *and* the selected trait, never color alone.
struct ExpenseCategoryGridView: View {
    let categories: [TransactionCategory]
    @Binding var selectedCategoryId: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(categories) { category in
                categoryCell(category)
            }
        }
    }

    private func categoryCell(_ category: TransactionCategory) -> some View {
        let isSelected = category.id == selectedCategoryId
        return Button {
            selectedCategoryId = category.id
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: category.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(verbatim: category.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                isSelected ? Theme.primaryTint : Theme.surface,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Theme.primary : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Category: \(category.name)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ExpenseCategoryGridView(
        categories: DemoSeed.makeCategories(),
        selectedCategoryId: .constant("groceries")
    )
    .padding()
    .background(Theme.background)
}
