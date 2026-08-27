import XCTest

/// The one UI smoke test (PRD §8), kept green as features land.
final class SmokeTests: XCTestCase {
    /// `-demoSkipOnboarding` jumps straight to the main shell; the Dashboard
    /// hero must be on screen.
    @MainActor
    func testSkipOnboardingLandsOnDashboardHero() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoSkipOnboarding"]
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["root.dashboard"]
                .waitForExistence(timeout: 10),
            "Dashboard hero did not appear after skip-onboarding launch"
        )
    }

    /// A default launch starts at the onboarding carousel.
    @MainActor
    func testDefaultLaunchShowsOnboarding() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.carousel"]
                .waitForExistence(timeout: 10),
            "Onboarding carousel did not appear on default launch"
        )
    }
}
