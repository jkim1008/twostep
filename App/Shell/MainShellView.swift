import SwiftUI

/// The five-surface shell (PRD §4 Navigation): tab bar ordered Expenses,
/// Budget, Dashboard (center — home and default), Savings, Recurring. Every
/// tab lives in its own `NavigationStack` and carries the shared household
/// chrome: avatar → Playbook, bell → Alert Center, FAB → Quick Add.
struct MainShellView: View {
    enum ShellTab: Hashable {
        case expenses
        case budget
        case dashboard
        case savings
        case recurring
    }

    @State private var selection: ShellTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            Tab("Expenses", systemImage: "list.bullet.rectangle.portrait", value: ShellTab.expenses) {
                shellTab { ExpensesView() }
            }
            Tab("Budget", systemImage: "chart.pie", value: ShellTab.budget) {
                shellTab { BudgetView() }
            }
            Tab("Dashboard", systemImage: "house", value: ShellTab.dashboard) {
                shellTab { DashboardView() }
            }
            Tab("Savings", systemImage: "sparkles", value: ShellTab.savings) {
                shellTab { SavingsView() }
            }
            Tab("Recurring", systemImage: "calendar", value: ShellTab.recurring) {
                shellTab { RecurringView() }
            }
        }
        .tint(Theme.primary)
    }

    private func shellTab(@ViewBuilder content: () -> some View) -> some View {
        NavigationStack {
            content()
                .modifier(HouseholdChromeModifier())
        }
    }
}

/// Shared chrome on all five surfaces (PRD §4 Navigation): partner avatar at
/// left (opens the Playbook), Alert Center bell with unread badge at right,
/// and the Quick Add FAB. Feature screens never wire these themselves.
private struct HouseholdChromeModifier: ViewModifier {
    @Environment(AppRepositories.self) private var repositories
    @State private var showPlaybook = false
    @State private var showAlertCenter = false
    @State private var showQuickAdd = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { avatarButton }
                ToolbarItem(placement: .topBarTrailing) { bellButton }
            }
            .overlay(alignment: .bottomTrailing) { quickAddButton }
            .sheet(isPresented: $showPlaybook) { PlaybookView() }
            .sheet(isPresented: $showAlertCenter) { AlertCenterView() }
            .sheet(isPresented: $showQuickAdd) { QuickAddView() }
    }

    private var avatarButton: some View {
        let member = repositories.households.currentMember
        let colorHex = member?.colorHex ?? DemoSeed.jointBadgeColorHex
        let initial = String(member?.displayName.prefix(1) ?? "?")
        return Button {
            showPlaybook = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hexString: colorHex))
                    .frame(width: 30, height: 30)
                Text(initial)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Open the Playbook")
    }

    private var bellButton: some View {
        let unread = repositories.events.unreadCount
        return Button {
            showAlertCenter = true
        } label: {
            Image(systemName: "bell")
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.danger, in: Capsule())
                            .padding(.top, 4)
                    }
                }
        }
        .accessibilityLabel(unread > 0 ? "Open Alert Center, \(unread) unread" : "Open Alert Center")
    }

    private var quickAddButton: some View {
        Button {
            showQuickAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.primary, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .padding(Theme.cardPadding)
        .accessibilityLabel("Quick Add")
    }
}

#Preview {
    MainShellView()
        .environment(DemoSeed.makeRepositories())
        .environment(ShellRouter(route: .main))
}
