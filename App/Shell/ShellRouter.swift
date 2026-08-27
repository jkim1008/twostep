import Foundation
import Observation

/// The app's top-level route (PRD §4.1 first-run flow → main shell).
enum ShellRoute: Hashable {
    case onboarding
    case signIn
    case invite
    case loading
    case main
}

/// Owns the top-level routing state. The demo skips straight to `.main`
/// when launched with the `-demoSkipOnboarding` argument (UI smoke test).
@MainActor
@Observable
final class ShellRouter {
    var route: ShellRoute

    init(route: ShellRoute) {
        self.route = route
    }
}
