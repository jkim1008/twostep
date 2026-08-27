import SwiftUI

/// Quick Add stub (PRD §4.3): the dial-pad entry sheet — amount keypad,
/// emoji-first category grid, attribution, slide-to-confirm — lands with the
/// Quick Add feature build. Presented from the FAB on every tab.
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                EmptyStateView(
                    systemImage: "plus.circle",
                    title: "Quick Add lands here",
                    message: "Dial-pad entry with slide-to-confirm — cash expenses in seconds, even offline."
                )
                .padding(.top, Theme.cardPadding * 3)
            }
            .background(Theme.background)
            .navigationTitle("Quick Add")
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
    QuickAddView()
        .environment(DemoSeed.makeRepositories())
}
