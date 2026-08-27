import XCTest

/// The one UI smoke test (PRD §8): launch → root renders.
/// Grows into launch → sign in (stubbed) → manual add → feed as features land.
final class SmokeTests: XCTestCase {
    @MainActor
    func testAppLaunchesToRootView() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["root.walkingSkeleton"]
                .waitForExistence(timeout: 10),
            "Root view did not appear after launch"
        )
    }
}
