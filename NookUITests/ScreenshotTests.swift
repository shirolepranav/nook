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
    func testP3Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launchArguments += ["-uiTestingCameraFixture"]
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        snap("H-01 Home with items")

        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))
        snap("H-02 Room with items")

        app.navigationBars["Kitchen"].buttons["More"].tap()
        app.buttons["Select"].tap()
        espresso.tap()
        snap("I-08 Multi-select")
        app.buttons["Cancel"].tap()

        espresso.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        snap("I-01 Item detail")
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        snap("I-02 Item editor")
        app.buttons["Cancel"].tap()

        app.buttons["Photo 1 of 1. Open photo viewer"].tap()
        snap("I-03 Photo viewer")
        app.buttons["Close"].tap()

        app.tab("Settings").tap()
        app.buttons["Recently Deleted"].tap()
        snap("S-08 Recently Deleted (empty)")
    }

    @MainActor
    func testP4Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))

        app.navigationBars["Kitchen"].buttons["More"].tap()
        app.buttons["Select"].tap()
        espresso.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stand mixer,")).firstMatch.tap()
        app.toolbars.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move 2 Items"].waitForExistence(timeout: 5))
        snap("I-04 Move picker, 2 items")
        app.buttons["Cancel"].tap()
        app.buttons["Cancel"].tap()

        espresso.tap()
        XCTAssertTrue(app.buttons["Move"].waitForExistence(timeout: 5))
        app.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move Espresso machine"].waitForExistence(timeout: 5))
        snap("I-04 Move picker")
        app.collectionViews.buttons.firstMatch.tap()
        snap("I-04 Moved, with Undo")

        let history = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Location history")).firstMatch
        for _ in 0..<6 where !(history.exists && history.isHittable) { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.navigationBars["Location history"].waitForExistence(timeout: 5))
        snap("I-05 Location history")
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
