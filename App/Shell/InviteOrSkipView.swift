import SwiftUI

/// Invite-or-skip step (PRD §4.1): joining with a partner is encouraged,
/// never forced at the door. Skipping plays the branded loading transition
/// and lands on the Dashboard; the invite stays reachable from the Playbook.
struct InviteOrSkipView: View {
    @Environment(ShellRouter.self) private var router

    var body: some View {
        VStack(spacing: Theme.cardSpacing * 2) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)

            Text("Invite your partner")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Two Step is built for two. Share this code so you both see the same numbers.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.cardPadding * 2)

            Text(verbatim: "DEMO-CODE")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(Theme.cardPadding)
                .background(Theme.primaryTint, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                .accessibilityLabel("Invite code: DEMO-CODE")

            Label("Demo mode — invites are simulated", systemImage: "sparkles")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Button {
                router.route = .loading
            } label: {
                Text("Skip for now")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .padding(.horizontal, Theme.cardPadding * 2)

            Button("Continue together") {
                router.route = .loading
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(minHeight: 44)
            .padding(.bottom, Theme.cardPadding)
        }
        .background(Theme.background)
    }
}

#Preview {
    InviteOrSkipView()
        .environment(ShellRouter(route: .invite))
}
