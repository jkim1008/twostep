import SwiftUI
import TwoStepCore

/// Root routing view. M0 walking skeleton — replaced by
/// onboarding/auth/main routing at M1.
struct RootView: View {
    var body: some View {
        VStack(spacing: Theme.cardSpacing) {
            Image(systemName: "figure.socialdance")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text("Two Step")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("One household. Two people. Same numbers.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .accessibilityIdentifier("root.walkingSkeleton")
    }
}

#Preview {
    RootView()
}
