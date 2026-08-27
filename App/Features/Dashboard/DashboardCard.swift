import SwiftUI

/// Shared module container for Dashboard sections (PRD §4.8): a titled
/// surface card with a trailing chevron hinting that the whole module
/// navigates into its owning tool.
struct DashboardCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
            }
            content
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

#Preview {
    DashboardCard(title: "At-risk budgets") {
        Text("Module content")
    }
    .padding()
    .background(Theme.background)
}
