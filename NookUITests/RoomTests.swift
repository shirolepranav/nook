import XCTest

final class RoomTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Smoke S2 / F1: a room with 3 spots in under 30 seconds.
    @MainActor
    func testCreateARoomWithThreeSpotsInUnder30Seconds() {
        let app = XCUIApplication.nook(store: "empty")
        app.launch()
        let addRoom = app.buttons["Add a Room"]
        XCTAssertTrue(addRoom.waitForExistence(timeout: 10))

        let start = Date.now
        addRoom.tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
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

    /// D14: deleting a room shows an Undo toast, and Undo brings it back.
    @MainActor
    func testDeleteARoomAndUndo() {
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
