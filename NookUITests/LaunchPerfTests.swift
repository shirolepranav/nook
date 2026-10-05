import XCTest

/// Cold launch to Home (PRD §9: under 400 ms on iPhone 15). A trend on the simulator; the
/// budget itself is checked on a real device. Opt-in, since 5 launches add about a minute:
/// TEST_RUNNER_RUN_PERF=1 xcodebuild test …
final class LaunchPerfTests: XCTestCase {
    @MainActor
    func testLaunchPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_PERF"] == "1", "set TEST_RUNNER_RUN_PERF=1")
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
