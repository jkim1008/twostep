import SwiftUI

/// Root of the app: routes onboarding → mock sign-in → invite-or-skip →
/// branded loading transition → main shell, and injects the repository set
/// every screen reads from.
struct AppShellView: View {
    @State private var repositories = DemoSeed.makeRepositories()
    @State private var router: ShellRouter

    init() {
        let skipOnboarding = ProcessInfo.processInfo.arguments.contains("-demoSkipOnboarding")
        _router = State(initialValue: ShellRouter(route: skipOnboarding ? .main : .onboarding))
    }

    var body: some View {
        Group {
            switch router.route {
            case .onboarding:
                OnboardingCarouselView()
            case .signIn:
                MockSignInView()
            case .invite:
                InviteOrSkipView()
            case .loading:
                LoadingTransitionView()
            case .main:
                MainShellView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.route)
        .environment(repositories)
        .environment(router)
    }
}

#Preview {
    AppShellView()
}
