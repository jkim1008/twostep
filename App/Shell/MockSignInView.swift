import SwiftUI

/// Demo sign-in: a name field and a continue button, clearly labeled as demo
/// mode. No account is created and no credentials are collected — real auth
/// (Sign in with Apple / email) replaces this screen later.
struct MockSignInView: View {
    @Environment(ShellRouter.self) private var router
    @Environment(AppRepositories.self) private var repositories
    @State private var name = "Maya"

    var body: some View {
        VStack(spacing: Theme.cardSpacing * 2) {
            Spacer()

            StepsMarkView()
                .frame(width: 72, height: 72)

            Text("Welcome to Two Step")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Your name")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                TextField("Name", text: $name)
                    .textContentType(.givenName)
                    .padding(Theme.cardPadding)
                    .frame(minHeight: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .accessibilityLabel("Your name")
            }
            .padding(.horizontal, Theme.cardPadding * 2)

            Button {
                repositories.households.signIn(named: name)
                router.route = .invite
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .padding(.horizontal, Theme.cardPadding * 2)

            Label("Demo mode — no account is created", systemImage: "sparkles")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            Spacer()
        }
        .background(Theme.background)
    }
}

#Preview {
    MockSignInView()
        .environment(ShellRouter(route: .signIn))
        .environment(DemoSeed.makeRepositories())
}
