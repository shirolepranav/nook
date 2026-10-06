import XCTest

/// P4: the Move picker (I-04), location history (I-05) and Move Container (H-03).
final class MoveTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        return app
    }

    @MainActor
    private func button(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func openEspressoMachine(_ app: XCUIApplication) {
        let kitchen = button(app, startingWith: "Kitchen,")
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        let card = button(app, startingWith: "Espresso machine,")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["Move"].waitForExistence(timeout: 5))
    }

    /// Picks Room → place inside the open picker.
    @MainActor
    private func pick(_ app: XCUIApplication, room: String, place: String) {
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5))
        // "Garage, 1 spot": a recent row would start "Garage," too.
        let roomRow = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "\(room), \\d+ spots?")).firstMatch
        roomRow.swipeUpUntilHittable(in: app.collectionViews.firstMatch)   // below the recents
        roomRow.tap()
        let placeRow = app.buttons["\(room), \(place)"]
        XCTAssertTrue(placeRow.waitForExistence(timeout: 5))
        placeRow.tap()
    }

    /// Smoke S4 / F6: Move → a recent place is 2 taps, the move shows in history, and the
    /// toast's Undo puts the item back.
    @MainActor
    func testMoveInTwoTapsShowsInHistoryAndUndoes() {
        let app = launch()
        openEspressoMachine(app)
        app.buttons["Move"].tap()                                           // tap 1
        let recent = app.collectionViews.buttons.firstMatch
        XCTAssertTrue(app.staticTexts["Recent"].waitForExistence(timeout: 5))
        recent.tap()                                                        // tap 2
        let toast = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moved to")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5))

        let history = button(app, startingWith: "Location history")
        history.swipeUpUntilHittable(in: app)
        XCTAssertTrue(app.staticTexts["2 places"].exists)
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.staticTexts["1 place"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kitchen, Counter"].exists)

        app.buttons["Move"].tap()
        XCTAssertTrue(app.staticTexts["Recent"].waitForExistence(timeout: 5))
        app.collectionViews.buttons.firstMatch.tap()
        history.swipeUpUntilHittable(in: app)
        history.tap()
        XCTAssertTrue(app.navigationBars["Location history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Moved by you"].exists)
        XCTAssertTrue(app.staticTexts["Added"].exists)
    }

    /// "Found it here instead" is its own kind of entry in history.
    @MainActor
    func testFoundItHereInsteadReadsAsFoundInHistory() {
        let app = launch()
        openEspressoMachine(app)
        app.buttons["Found It Here Instead"].tap()
        XCTAssertTrue(app.navigationBars["Where did you find it?"].waitForExistence(timeout: 5))
        pick(app, room: "Garage", place: "Metal shelf")
        XCTAssertTrue(app.staticTexts["Found in Garage → Metal shelf."].waitForExistence(timeout: 5))
        let history = button(app, startingWith: "Location history")
        history.swipeUpUntilHittable(in: app)
        history.tap()
        XCTAssertTrue(app.staticTexts["Found here by you"].waitForExistence(timeout: 5))
    }

    /// I-08: two selected items move together.
    @MainActor
    func testMoveTwoSelectedItems() {
        let app = launch()
        let kitchen = button(app, startingWith: "Kitchen,")
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        app.navigationBars.buttons["More"].tap()
        app.buttons["Select"].tap()
        button(app, startingWith: "Espresso machine,").tap()
        button(app, startingWith: "Stand mixer,").tap()
        app.toolbars.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move 2 Items"].waitForExistence(timeout: 5))
        pick(app, room: "Garage", place: "Metal shelf")
        XCTAssertTrue(app.staticTexts["Moved 2 items to Garage → Metal shelf."].waitForExistence(timeout: 5))
        XCTAssertTrue(button(app, startingWith: "Espresso machine,").waitForNonExistence(timeout: 5))
        XCTAssertFalse(button(app, startingWith: "Stand mixer,").exists)
    }

    /// H-03: a container moves with what's inside it, and its items' history says so.
    @MainActor
    func testMoveAContainerCarriesItsItems() {
        let app = launch()
        let garage = button(app, startingWith: "Garage,")
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        garage.tap()
        app.buttons["Metal shelf"].tap()
        let box = button(app, startingWith: "Box 14")
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        box.tap()
        XCTAssertTrue(app.navigationBars["Box 14"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["More"].tap()
        app.buttons["Move Container"].tap()
        pick(app, room: "Kitchen", place: "Pantry")
        XCTAssertTrue(app.staticTexts["Moved Box 14 to Kitchen → Pantry."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kitchen, Pantry"].waitForExistence(timeout: 5))   // the breadcrumb

        button(app, startingWith: "Camping tent,").tap()
        XCTAssertTrue(app.staticTexts["Kitchen, Pantry, Box 14"].waitForExistence(timeout: 5))
    }

    /// 01 §1.5: ⇧⌘M opens Move for the item on screen. Menu shortcuts only fire on iPad in
    /// XCUITest (P2 notes), so the iPhone runs skip it.
    @MainActor
    func testShiftCommandMOpensMove() throws {
        let app = launch()
        try XCTSkipUnless(app.windows.firstMatch.horizontalSizeClass == .regular,
                          "hardware-keyboard shortcuts are checked on iPad (D29)")
        openEspressoMachine(app)
        app.typeKey("m", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.navigationBars["Move Espresso machine"].waitForExistence(timeout: 5))
    }
}

extension XCUIElement {
    /// Scrolls up until this element can be tapped (for rows below the fold on SE).
    @MainActor
    func swipeUpUntilHittable(in scroller: XCUIElement, attempts: Int = 6) {
        var left = attempts
        while !(exists && isHittable), left > 0 {
            scroller.swipeUp()
            left -= 1
        }
    }
}
