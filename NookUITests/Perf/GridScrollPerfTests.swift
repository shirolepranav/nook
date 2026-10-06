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
        // From here, no queries on the app: a full accessibility snapshot of a 1,000-card grid
        // times out XCUITest. Swipes go through SpringBoard's coordinates, whose tree is tiny;
        // the touches still land on Nook in front.
        sleep(2)
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let low = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let high = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            low.press(forDuration: 0.01, thenDragTo: high, withVelocity: .fast, thenHoldForDuration: 0)
            stopMeasuring()
            high.press(forDuration: 0.01, thenDragTo: low, withVelocity: .fast, thenHoldForDuration: 0)
        }
    }
}
