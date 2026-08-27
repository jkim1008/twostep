import SwiftUI

/// Category chip: emoji-first identity, always paired with the category name
/// (DESIGN.md §1 principle 3 — never emoji alone).
struct EmojiCategoryChip: View {
    let emoji: String
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.caption)
                .accessibilityHidden(true)
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.primaryTint, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Category: \(name)"))
    }
}

#Preview {
    HStack {
        EmojiCategoryChip(emoji: "🛒", name: "Groceries")
        EmojiCategoryChip(emoji: "🍽️", name: "Dining")
    }
    .padding()
    .background(Theme.background)
}
