import XCTest

/// Screenshots of each screen a phase touches, for its PR and QA report (02 Definition of
/// Done). Opt-in; set the simulator's appearance and text size first, then:
/// TEST_RUNNER_RUN_SCREENSHOTS=1 xcodebuild test -only-testing:NookUITests/ScreenshotTests …
/// and export the attachments from the result bundle.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testP2Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let onboarding = XCUIApplication.nook(onboarded: false)
        onboarding.launch()
        XCTAssertTrue(onboarding.buttons["Get Started"].waitForExistence(timeout: 10))
        snap("O-01 Welcome")
        onboarding.buttons["Get Started"].tap()
        XCTAssertTrue(onboarding.buttons["Continue with 4 rooms"].waitForExistence(timeout: 5))
        snap("O-02 Pick your rooms")
        onboarding.terminate()

        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let kitchen = app.buttons["Kitchen, Empty"]
        XCTAssertTrue(kitchen.waitForExistence(timeout: 10))
        snap("H-01 Home")

        kitchen.tap()
        XCTAssertTrue(app.navigationBars["Kitchen"].waitForExistence(timeout: 5))
        snap("H-02 Room")

        if !app.buttons["Edit Room"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Edit Room"].tap()
        XCTAssertTrue(app.navigationBars["Edit Room"].waitForExistence(timeout: 5))
        snap("H-04 Room editor")
        app.buttons["Cancel"].tap()

        if !app.buttons["Arrange Spots"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Arrange Spots"].tap()
        XCTAssertTrue(app.navigationBars["Arrange Spots"].waitForExistence(timeout: 5))
        snap("H-07 Arrange spots")
        app.buttons["Cancel"].tap()

        app.buttons["Counter"].tap()
        XCTAssertTrue(app.navigationBars["Counter"].waitForExistence(timeout: 5))
        snap("H-03 Spot")
        app.buttons["Add container"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
        snap("H-05 Container editor")
    }

    @MainActor
    private func snap(_ name: String) {
        sleep(1)   // let transitions settle
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
