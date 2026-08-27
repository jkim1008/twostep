import XCTest

/// Headless screenshot tour — one test per surface, driven by the demo
/// launch arguments. Used for overnight verification and, later, App Store
/// screenshot automation. Attachments are exported from the xcresult bundle.
final class ScreenTourTests: XCTestCase {
    @MainActor
    private func capture(_ name: String, args: [String], dark: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = args
        if dark {
            app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        }
        app.launch()
        let settled = app.wait(for: .runningForeground, timeout: 10)
        XCTAssertTrue(settled, "App did not reach foreground for \(name)")
        Thread.sleep(forTimeInterval: 3)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    @MainActor func test01Onboarding() { capture("01-onboarding", args: []) }
    @MainActor func test02Dashboard() { capture("02-dashboard", args: ["-demoSkipOnboarding"]) }
    @MainActor func test03Expenses() { capture("03-expenses", args: ["-demoSkipOnboarding", "-demoInitialTab", "expenses"]) }
    @MainActor func test04Budget() { capture("04-budget", args: ["-demoSkipOnboarding", "-demoInitialTab", "budget"]) }
    @MainActor func test05Savings() { capture("05-savings", args: ["-demoSkipOnboarding", "-demoInitialTab", "savings"]) }
    @MainActor func test06Recurring() { capture("06-recurring", args: ["-demoSkipOnboarding", "-demoInitialTab", "recurring"]) }
    @MainActor func test07AlertCenter() { capture("07-alert-center", args: ["-demoSkipOnboarding", "-demoPresent", "alerts"]) }
    @MainActor func test08Playbook() { capture("08-playbook", args: ["-demoSkipOnboarding", "-demoPresent", "playbook"]) }
    @MainActor func test09QuickAdd() { capture("09-quickadd", args: ["-demoSkipOnboarding", "-demoPresent", "quickadd"]) }
    @MainActor func test10DashboardDark() { capture("10-dashboard-dark", args: ["-demoSkipOnboarding"], dark: true) }
    @MainActor func test11BudgetDark() { capture("11-budget-dark", args: ["-demoSkipOnboarding", "-demoInitialTab", "budget"], dark: true) }
}
