import XCTest

/// O-01 → O-02 → Home on first run, with the picked rooms created (01 §4).
final class OnboardingTests: XCTestCase {
    @MainActor
    func testFirstRunPicksRoomsAndLandsOnHome() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(onboarded: false)
        app.launch()

        let getStarted = app.buttons["Get Started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()

        // Four rooms come picked (the board); take Office off and Garage on.
        XCTAssertTrue(app.buttons["Continue with 4 rooms"].waitForExistence(timeout: 5))
        app.buttons["Office"].tap()
        app.buttons["Garage"].tap()

        // A room of your own.
        app.buttons["Add your own"].tap()
        let field = app.textFields["Room name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Studio\n")
        XCTAssertTrue(app.buttons["Studio"].isSelected)

        app.buttons["Continue with 5 rooms"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
    }
}
