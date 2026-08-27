import SwiftUI

/// Playbook stub (PRD §4.10): the household command center behind the header
/// avatar — never a tab. Member management, linked banks, categories,
/// notifications, export, and deletion land with the Playbook feature build.
struct PlaybookView: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Household") {
                    Text(repositories.households.household.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    ForEach(repositories.households.members) { member in
                        HStack {
                            PartnerBadge(name: member.displayName, colorHex: member.colorHex)
                            Spacer()
                            Text(member.role == .owner ? "Owner" : "Partner")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                Section {
                    Text("Linked banks, categories, notification preferences, export, and account management land here.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .navigationTitle("Playbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}

#Preview {
    PlaybookView()
        .environment(DemoSeed.makeRepositories())
}
