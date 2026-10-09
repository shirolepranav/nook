import XCTest

/// P7: warranties (F4) and lending (F7). Smoke S7: add a warranty and see its reminders;
/// lend an item and see it under Lent out.
final class WarrantyAndLendTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ store: String, notifications: String = "granted") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: store)
        app.launchArguments += ["-uiTestingCameraFixture", "-uiTestingNotifications", notifications]
        app.launch()
        return app
    }

    @MainActor
    private func card(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    @MainActor
    private func text(_ app: XCUIApplication, containing words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// S7 (warranty half), I-02 → I-01 → R-04: a 2-year warranty from today, reminders 30 and
    /// 7 days before; then R-04's swipe turns them off.
    @MainActor
    func testWarrantyFromTheEditorShowsOnItemAndInWarranties() {
        let app = launch("small")
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 10))
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 5))
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        name.typeText("Dishwasher\n")

        let twoYears = app.buttons["2 yrs"]
        for _ in 0..<6 where !twoYears.isHittable { app.swipeUp() }
        twoYears.tap()
        XCTAssertTrue(text(app, containing: "Reminders 30 and 7 days before.").waitForExistence(timeout: 5))
        app.buttons["Save"].tap()

        let dishwasher = card(app, "Dishwasher")
        XCTAssertTrue(dishwasher.waitForExistence(timeout: 5))
        dishwasher.tap()
        XCTAssertTrue(text(app, containing: "Reminders 30 and 7 days before").waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "Active").exists)

        app.tab("Reports").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Warranties'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Warranties"].waitForExistence(timeout: 5))
        let row = app.cells.containing(.staticText, identifier: "Dishwasher").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Reminders Off"].tap()
        XCTAssertTrue(app.staticTexts["Reminders off."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Reminders off"].waitForExistence(timeout: 5))
    }

    /// S7 (lending half), I-06 → I-01 → R-05: lend with a typed name, see the badge and the
    /// Lent out list, Mark Returned with a swipe, then Undo.
    @MainActor
    func testLendShowsBadgeAndLentOutThenMarkReturnedUndoes() {
        let app = launch("lived")
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Kitchen,'")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        let espresso = card(app, "Espresso machine")
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))
        espresso.tap()
        app.navigationBars.buttons["More"].tap()
        app.buttons["Lend"].tap()
        let who = app.textFields["Who has it?"]
        XCTAssertTrue(who.waitForExistence(timeout: 5))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) { who.tap() }
        who.typeText("Jordan")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Lent to Jordan."].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "has it since").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark Returned"].exists)

        app.tab("Reports").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lent out'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Lent out"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "3 days late").waitForExistence(timeout: 5))   // Sam's mixer, first
        let row = app.cells.containing(.staticText, identifier: "Espresso machine").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Mark Returned"].tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Espresso machine").firstMatch.waitForExistence(timeout: 5))
    }

    /// H-01's row (D4) and See All → R-04.
    @MainActor
    func testHomeShowsWarrantiesEndingSoon() {
        let app = launch("lived")
        let drill = app.buttons["Cordless drill, warranty ends in 20 days"]
        for _ in 0..<4 where !drill.exists { app.swipeUp() }
        XCTAssertTrue(drill.waitForExistence(timeout: 10))
        app.buttons["See all warranties"].tap()
        XCTAssertTrue(app.navigationBars["Warranties"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ending in 30 days"].exists)
        XCTAssertTrue(app.staticTexts["Expired"].exists)
    }

    /// 01 §13: with notifications off, the warranty card and S-07 say so and offer Settings.
    @MainActor
    func testDeniedNotificationsShowTheWayToSettings() {
        let app = launch("lived", notifications: "denied")
        let garage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Garage,'")).firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        garage.tap()
        card(app, "Cordless drill").tap()
        let off = app.staticTexts["Reminders are off for Nook."]
        for _ in 0..<4 where !off.exists { app.swipeUp() }
        XCTAssertTrue(off.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].exists)

        app.tab("Settings").tap()
        app.buttons["Notifications"].tap()
        XCTAssertTrue(app.staticTexts["Reminders are off for Nook"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Warranty reminders"].exists)
    }
}
