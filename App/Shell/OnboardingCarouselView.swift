import SwiftUI

/// Pre-account feature carousel (PRD §4.1): swipeable sage-branded pages,
/// one idea per page, with "Get started" reachable from every page and a
/// skip affordance. No data is collected here.
struct OnboardingCarouselView: View {
    @Environment(ShellRouter.self) private var router
    @State private var pageIndex = 0

    private static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: "feed", systemImage: "list.bullet.rectangle.portrait",
            title: "One shared feed",
            message: "Every transaction from both of you, in one place — attributed, never audited."
        ),
        OnboardingPage(
            id: "budget", systemImage: "chart.pie",
            title: "Budgets you both see",
            message: "One set of monthly budgets, updating live on both phones."
        ),
        OnboardingPage(
            id: "savings", systemImage: "sparkles",
            title: "Save for things together",
            message: "Shared projects — a trip, a couch — moved forward by both of you."
        ),
        OnboardingPage(
            id: "sync", systemImage: "calendar.badge.clock",
            title: "A five-minute weekly sync",
            message: "The same numbers, at the same moment, once a week. That's the whole ritual."
        )
    ]

    var body: some View {
        VStack(spacing: Theme.cardSpacing) {
            HStack {
                Spacer()
                Button("Skip") { router.route = .signIn }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, Theme.cardPadding)

            TabView(selection: $pageIndex) {
                ForEach(Array(Self.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .accessibilityIdentifier("onboarding.carousel")

            Button {
                router.route = .signIn
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, Theme.cardPadding)
        }
        .background(Theme.background)
    }
}

private struct OnboardingPage: Identifiable {
    let id: String
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Theme.cardSpacing * 2) {
            ZStack {
                Circle()
                    .fill(Theme.primaryTint)
                    .frame(width: 140, height: 140)
                Image(systemName: page.systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.primary)
            }
            .accessibilityHidden(true)
            Text(page.title)
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(page.message)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.cardPadding * 2)
        }
        .padding(.bottom, Theme.cardPadding * 3)
    }
}

#Preview {
    OnboardingCarouselView()
        .environment(ShellRouter(route: .onboarding))
}
