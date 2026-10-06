import XCTest

/// Scrolling a 1,000-item grid (PRD §9: 120 fps on ProMotion, no dropped frames). A trend on
/// the simulator; the budget itself is checked on a real ProMotion iPhone with Instruments.
/// Opt-in like the launch test: TEST_RUNNER_RUN_PERF=1 xcodebuild test …
final class GridScrollPerfTests: XCTestCase {
    @MainActor
    func testScrollingAThousandItems() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_PERF"] == "1", "set TEST_RUNNER_RUN_PERF=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "items1k")
        app.launch()
        let storage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Storage,")).firstMatch
        XCTAssertTrue(storage.waitForExistence(timeout: 30))
        storage.tap()
        XCTAssertTrue(app.navigationBars["Storage"].waitForExistence(timeout: 10))

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            app.swipeUp(velocity: .fast)
            stopMeasuring()
            app.swipeDown(velocity: .fast)
        }
    }
}
