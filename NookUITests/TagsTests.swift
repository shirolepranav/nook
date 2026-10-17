import XCTest

/// S-10 Tags (P13, D63): rename, merge, delete with Undo, and a tag's items.
final class TagsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func row(_ app: XCUIApplication, _ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(prefix),")).firstMatch
    }

    @MainActor
    func testRenameMergeDeleteAndOpenATag() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        app.tab("Settings").tap()
        app.settingsRow("Tags").tap()
        XCTAssertTrue(row(app, "Baking").waitForExistence(timeout: 5))

        // Rename Baking → Baking gear (appending: clearing an alert's field is unreliable).
        row(app, "Baking").swipeLeft()
        app.buttons["Rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(" gear")
        app.alerts.buttons["Rename"].tap()
        XCTAssertTrue(row(app, "Baking gear").waitForExistence(timeout: 5))

        // Merge Coffee into Baking gear: one tag, two items.
        row(app, "Coffee").swipeLeft()
        app.buttons["Merge"].tap()
        app.buttons["Baking gear"].tap()
        XCTAssertTrue(app.buttons["Baking gear, 2 items"].waitForExistence(timeout: 5))
        XCTAssertFalse(row(app, "Coffee").exists)

        // Delete it, then Undo from the toast.
        row(app, "Baking gear").swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertFalse(row(app, "Baking gear").waitForExistence(timeout: 2))
        app.buttons["Undo"].tap()
        XCTAssertTrue(row(app, "Baking gear").waitForExistence(timeout: 5))

        // A tag opens its items.
        row(app, "Power tools").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Cordless drill,'")).firstMatch
            .waitForExistence(timeout: 5))
    }
}

