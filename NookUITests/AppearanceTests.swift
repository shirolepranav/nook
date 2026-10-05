import XCTest

/// S-06: the accent and theme the user picks survive a relaunch.
final class AppearanceTests: XCTestCase {
    @MainActor
    func testAccentAndThemePersist() {
        let app = XCUIApplication()
        app.launch()
        openAppearance(app)
        app.buttons["Sage"].tap()
        app.segmentedControls.buttons["Dark"].tap()

        app.terminate()
        app.launch()
        openAppearance(app)
        XCTAssertTrue(app.buttons["Sage"].isSelected)
        XCTAssertTrue(app.segmentedControls.buttons["Dark"].isSelected)

        // Put the defaults back for the other tests.
        app.buttons["Terracotta"].tap()
        app.segmentedControls.buttons["System"].tap()
    }

    @MainActor
    private func openAppearance(_ app: XCUIApplication) {
        app.tab("Settings").tap()
        app.buttons["Appearance"].tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
    }
}
