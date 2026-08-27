import SwiftUI

/// Alert Center stub (PRD §4.9): the household activity feed behind the
/// header bell. Rows render from the event repository; opening marks the
/// viewer's cursor seen (their device only). Deep links and derived
/// partner-activity rows land with the Alert Center feature build.
struct AlertCenterView: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(repositories.events.events) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.payload)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(event.timestamp, style: .date)
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, 2)
                .listRowBackground(Theme.background)
            }
            .listStyle(.plain)
            .background(Theme.background)
            .navigationTitle("Alert Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onAppear { repositories.events.markAllSeen() }
        }
    }
}

#Preview {
    AlertCenterView()
        .environment(DemoSeed.makeRepositories())
}
