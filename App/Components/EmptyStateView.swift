import SwiftUI

/// Friendly empty state (DESIGN.md §6): simple visual + copy + the next
/// action. Never a blank screen.
struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.cardSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
            }
        }
        .padding(Theme.cardPadding * 2)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "chart.pie",
        title: "No budget yet",
        message: "Set an allocation for a category to see progress here.",
        actionTitle: "Set a budget",
        action: {}
    )
    .background(Theme.background)
}
