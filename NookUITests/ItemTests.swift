import XCTest

final class ItemTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(_ store: String) -> XCUIApplication {
        let app = XCUIApplication.nook(store: store)
        app.launchArguments += ["-uiTestingCameraFixture"]   // simulators have no camera (D37)
        app.launch()
        return app
    }

    @MainActor
    private func card(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    /// Smoke S3 / F2: a photo and a name in 2 taps (shutter, Save); edit it; delete it;
    /// restore it from Recently Deleted.
    @MainActor
    func testAddInTwoTapsEditDeleteAndRestore() {
        let app = launch("small")
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 10))
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 5))
        app.buttons["Add item"].tap()

        let shutter = app.buttons["Take Photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()                                               // tap 1
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["Photo 1"].waitForExistence(timeout: 5) || app.images.count > 0)
        name.typeText("Mug")                                        // the field is focused
        app.buttons["Save"].tap()                                   // tap 2
        let mug = card(app, "Mug")
        XCTAssertTrue(mug.waitForExistence(timeout: 5))

        mug.tap()
        app.buttons["Edit"].tap()
        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(" cup")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Mug cup"].waitForExistence(timeout: 5))

        app.navigationBars.buttons["More"].tap()
        app.buttons["Delete"].tap()
        app.sheets.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(card(app, "Mug cup").waitForNonExistence(timeout: 5))

        app.tab("Settings").tap()
        app.buttons["Recently Deleted"].tap()
        XCTAssertTrue(app.staticTexts["Mug cup"].waitForExistence(timeout: 5))
        app.buttons["Restore"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nothing deleted."].waitForExistence(timeout: 5))
        app.tab("Home").tap()
        XCTAssertTrue(card(app, "Mug cup").waitForExistence(timeout: 5))
    }

    /// I-02: cancelling with changes asks first.
    @MainActor
    func testCancelWithChangesAsksToDiscard() {
        let app = launch("small")
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 10))
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 5))
        app.buttons["Add item"].tap()
        app.buttons["Cancel"].firstMatch.tap()                      // the fixture camera's Cancel
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 5))

        app.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 5))
        app.buttons["Add item"].tap()
        app.buttons["Take Photo"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Lamp")
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard Changes"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertFalse(card(app, "Lamp").exists)
    }

    /// I-08 and D14: select two items, delete them, and Undo brings both back.
    @MainActor
    func testSelectTwoDeleteAndUndo() {
        let app = launch("lived")
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        app.navigationBars.buttons["More"].tap()
        app.buttons["Select"].tap()
        card(app, "Espresso machine").tap()
        card(app, "Stand mixer").tap()
        XCTAssertTrue(app.navigationBars["2 Selected"].waitForExistence(timeout: 5))
        app.toolbars.buttons["Delete"].tap()
        app.buttons["Delete 2 Items"].tap()
        XCTAssertTrue(card(app, "Espresso machine").waitForNonExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(card(app, "Espresso machine").waitForExistence(timeout: 5))
        XCTAssertTrue(card(app, "Stand mixer").exists)
    }

    /// D28: deleting a room that holds items can send them to Recently Deleted.
    @MainActor
    func testDeleteARoomWithItemsSendsThemToRecentlyDeleted() {
        let app = launch("lived")
        let garage = app.buttons["Garage, 3 items"]
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        sleep(1)   // let the cards' photos finish loading, or the long press lands as a tap
        garage.press(forDuration: 1.5)
        app.buttons["Delete"].tap()
        app.buttons["Move Items to Recently Deleted"].tap()
        XCTAssertTrue(garage.waitForNonExistence(timeout: 5))
        app.tab("Settings").tap()
        app.buttons["Recently Deleted"].tap()
        XCTAssertTrue(app.staticTexts["Cordless drill"].waitForExistence(timeout: 5))
    }
}
