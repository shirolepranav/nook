import XCTest

/// P5: Find (F-01), results (F-02), answer cards (F-03), filters (F-05) and saved searches
/// (F-06), on the `lived` store.
final class FindTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openFind(_ arguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launchArguments += arguments
        app.launch()
        app.tab("Find").tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func search(_ app: XCUIApplication, _ text: String) {
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func text(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Smoke S5 / F5: a typo still finds the item, and the answer card shows where it is and
    /// when that was last confirmed.
    @MainActor
    func testATypoAnswersWithLocationAndLastConfirmed() {
        let app = openFind()
        search(app, "skillet")   // warm up: the index builds after launch
        XCTAssertTrue(app.otherElements["Answer"].waitForExistence(timeout: 10))
        app.searchFields.firstMatch.buttons["Clear text"].tap()
        search(app, "skilet")
        let answer = app.otherElements["Answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 2))
        XCTAssertTrue(answer.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Kitchen")).firstMatch.exists)
        XCTAssertTrue(answer.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Last confirmed")).firstMatch.exists)
        XCTAssertTrue(answer.buttons["Move"].exists)
    }

    /// F-03 variants from records: lent, room contents, quantity, and a synonym.
    @MainActor
    func testQuestionsAnswerFromRecords() {
        let app = openFind()
        search(app, "Who has my drill?")
        XCTAssertTrue(text(app, startingWith: "Jordan").waitForExistence(timeout: 10))
        app.searchFields.firstMatch.buttons["Clear text"].tap()

        search(app, "What’s in the garage?")
        XCTAssertTrue(text(app, startingWith: "3 things in").waitForExistence(timeout: 5))
        app.searchFields.firstMatch.buttons["Clear text"].tap()

        search(app, "Do I have any AA batteries?")
        XCTAssertTrue(app.staticTexts["Yes, you have 2."].waitForExistence(timeout: 5))
        app.searchFields.firstMatch.buttons["Clear text"].tap()

        search(app, "fob")   // synonyms.json: fob → key
        XCTAssertTrue(app.otherElements["Answer"].staticTexts["Spare car key"].waitForExistence(timeout: 5))
    }

    /// F-02: Move from a result row, then Undo from the toast. "kitchen" answers with the
    /// room's contents and lists its items as rows.
    @MainActor
    func testMoveFromAResultAndUndo() {
        let app = openFind()
        search(app, "kitchen")
        let move = app.buttons["Move Olive oil"]
        XCTAssertTrue(app.otherElements["Answer"].waitForExistence(timeout: 10))
        for _ in 0..<6 where !(move.exists && move.isHittable) { app.collectionViews.firstMatch.swipeUp() }
        move.tap()                                                          // tap 1
        XCTAssertTrue(app.staticTexts["Recent"].waitForExistence(timeout: 5))
        app.collectionViews.buttons.firstMatch.tap()                        // tap 2
        let toast = text(app, startingWith: "Moved to")
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(toast.waitForExistence(timeout: 2) && toast.isHittable)
    }

    /// F-02: private items are listed masked, and nothing matching offers to add it.
    @MainActor
    func testPrivateResultsAreMaskedAndNoResultsOffersAdd() {
        let app = openFind(["-uiTestingCameraFixture"])
        search(app, "passport")
        XCTAssertTrue(app.buttons["Private item. Unlock to see it"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["Answer"].exists)                  // private never answers
        XCTAssertFalse(app.staticTexts["Passport"].exists)
        app.searchFields.firstMatch.buttons["Clear text"].tap()

        search(app, "skis")
        XCTAssertTrue(app.staticTexts["Nothing called “skis” yet."].waitForExistence(timeout: 5))
        app.buttons["Add “skis” as an Item"].tap()
        let shutter = app.buttons["Take Photo"]   // quick add starts with the camera (D37)
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["Name"].value as? String, "skis")
    }

    /// F-05 and F-06: filter by room, save the search, run it again, rename, delete.
    @MainActor
    func testFilterSaveRenameAndDeleteASearch() {
        let app = openFind()
        app.buttons["Filters"].firstMatch.tap()
        let garage = app.buttons["Garage"]
        XCTAssertTrue(garage.waitForExistence(timeout: 5))
        garage.tap()
        let show = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Show ")).firstMatch
        XCTAssertEqual(show.label, "Show 3 Items")
        app.buttons["Save Search"].tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Garage stuff")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Remove filter: Garage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cordless drill,")).firstMatch.exists)

        app.buttons["Remove filter: Garage"].tap()                          // back to the start
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Garage stuff")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.swipeLeft()
        app.buttons["Rename"].tap()
        let rename = app.alerts.textFields.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.clearAndType("Tools")
        app.alerts.buttons["Rename"].tap()
        let tools = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Tools")).firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 5))
        tools.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertFalse(tools.waitForExistence(timeout: 2))
    }
}

extension XCUIElement {
    /// Replaces a field's text.
    @MainActor
    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
