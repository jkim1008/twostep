import SwiftUI
import TwoStepCore

/// "To discuss" row (PRD §4.8): visible only while unresolved discussion
/// flags exist, linking to the Weekly Sync — the flags' ritual home. Flags
/// carry no urgency channel (§4.7.2), so this is a calm count, not an alert.
struct DashboardDiscussRow: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        if flaggedCount > 0 {
            NavigationLink {
                WeeklySyncView()
            } label: {
                DashboardCard(title: "To discuss") {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundStyle(Theme.primary)
                            .accessibilityHidden(true)
                        Text("^[\(flaggedCount) expense](inflect: true) flagged for this week's Sync")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the Weekly Sync"))
        }
    }

    private var flaggedCount: Int {
        repositories.transactions.transactions.count { $0.isAwaitingDiscussion }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DashboardDiscussRow()
                .padding()
        }
        .background(Theme.background)
    }
    .environment(DemoSeed.makeRepositories())
}
