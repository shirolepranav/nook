import XCTest

final class ArrangeAndSidebarTests: XCTestCase {
    /// H-07: drag a room to the top, Done, and Home shows the new order.
    @MainActor
    func testArrangeRooms() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let kitchen = app.buttons["Kitchen, Empty"]
        XCTAssertTrue(kitchen.waitForExistence(timeout: 10))
        kitchen.press(forDuration: 1)
        app.buttons["Arrange Rooms"].tap()

        let garageHandle = app.buttons["Reorder Garage"]
        XCTAssertTrue(garageHandle.waitForExistence(timeout: 5))
        garageHandle.press(forDuration: 0.5, thenDragTo: app.buttons["Reorder Kitchen"])
        app.buttons["Done"].tap()

        let garage = app.buttons["Garage, Empty"]
        XCTAssertTrue(garage.waitForExistence(timeout: 5))
        // Garage now comes first: above Kitchen, or level with it and to its left.
        let g = garage.frame, k = kitchen.frame
        XCTAssertTrue(g.minY < k.minY || (g.minY == k.minY && g.minX < k.minX), "Garage should lead")
    }

    /// 01 H-01 regular width: rooms in the sidebar, the room beside it; ⌘E edits it.
    @MainActor
    func testRoomsInTheSidebar() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication.nook(store: "small")
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        try XCTSkipUnless(app.windows.firstMatch.frame.width >= 900, "compact width: no sidebar")

        let bedroom = app.cells["Bedroom"]
        XCTAssertTrue(bedroom.waitForExistence(timeout: 5))
        bedroom.tap()
        XCTAssertTrue(app.navigationBars["Bedroom"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wardrobe"].exists)

        app.typeKey("e", modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Edit Room"].waitForExistence(timeout: 5))
    }
}
