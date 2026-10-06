import XCTest

final class RoomTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Smoke S2 / F1: a room with 3 spots in under 30 seconds.
    @MainActor
    func testCreateARoomWithThreeSpotsInUnder30Seconds() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "empty")
        app.launch()
        let addRoom = app.buttons["Add a Room"]
        XCTAssertTrue(addRoom.waitForExistence(timeout: 10))

        let start = Date.now
        addRoom.tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))   // a freshly booted simulator's first keyboard is slow
        name.typeText("Office\n")                      // Return goes straight to the first spot
        let spot = app.textFields["Spot name"]
        XCTAssertTrue(spot.waitForExistence(timeout: 5))
        spot.typeText("Desk\nShelf\nCloset\n")         // Return keeps the next spot field open
        app.buttons["Save"].tap()
        let card = app.buttons["Office, Empty"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let elapsed = Date.now.timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 30, "F1: took \(Int(elapsed)) s")

        card.tap()
        for spot in ["Desk", "Shelf", "Closet"] {
            XCTAssertTrue(app.staticTexts[spot].waitForExistence(timeout: 5), spot)
        }
    }

    /// P2 QA: 50+ rooms scroll on Home, and a very long room and spot name open and wrap.
    @MainActor
    func testManyRoomsAndLongNames() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "many")
        app.launch()
        XCTAssertTrue(app.buttons["Room 1, Empty"].waitForExistence(timeout: 10))
        let long = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "The spare bedroom")).firstMatch
        for _ in 0..<30 where !(long.exists && long.isHittable) { app.swipeUp() }
        XCTAssertTrue(long.isHittable)
        long.tap()
        XCTAssertTrue(app.buttons["The tall wardrobe with the sliding mirror doors on the left"]
            .waitForExistence(timeout: 5))
    }

    /// D14: deleting a room shows an Undo toast, and Undo brings it back.
    @MainActor
    func testDeleteARoomAndUndo() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let garage = app.buttons["Garage, Empty"]
        XCTAssertTrue(garage.waitForExistence(timeout: 10))
        garage.press(forDuration: 1)
        app.buttons["Delete"].tap()
        app.buttons["Delete Room"].tap()
        XCTAssertTrue(garage.waitForNonExistence(timeout: 5))

        app.buttons["Undo"].tap()
        XCTAssertTrue(garage.waitForExistence(timeout: 5))
    }
}

final class SpotTests: XCTestCase {
    /// H-02, H-03, H-05 and D34: a container on the room's floor, another inside a spot.
    @MainActor
    func testAddContainersOnTheFloorAndInsideASpot() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let garage = app.buttons["Garage, Empty"]
        XCTAssertTrue(garage.waitForExistence(timeout: 10))
        garage.tap()

        // On the floor (D34).
        app.buttons["Add"].tap()
        app.buttons["Add Container"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Toolbox")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Toolbox"].waitForExistence(timeout: 5))

        // Inside a spot, from the spot's own screen.
        app.buttons["Metal shelf"].tap()
        XCTAssertTrue(app.navigationBars["Metal shelf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Box 14"].exists)
        app.buttons["Add container"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Paint cans")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Paint cans"].waitForExistence(timeout: 5))

        // A container opens to its own screen.
        app.buttons["Box 14"].tap()
        XCTAssertTrue(app.navigationBars["Box 14"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Garage, Metal shelf"].exists)   // the arrow reads as a comma
    }
}
