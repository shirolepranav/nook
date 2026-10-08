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
        if app.windows.firstMatch.frame.width < 600 {   // D35: room tabs stay out of the tab bar
            XCTAssertFalse(app.tabBars.buttons["Kitchen"].exists, "rooms are sidebar-only")
        } else {   // iPad portrait: the floating bar has no Rooms group (iPadHome board)
            XCTAssertFalse(app.buttons["Rooms"].exists, "rooms are sidebar-only")
        }
        kitchen.press(forDuration: 1)
        app.buttons["Arrange Rooms"].tap()

        let garageHandle = app.buttons["Reorder Garage"]
        XCTAssertTrue(garageHandle.waitForExistence(timeout: 5))
        // Slow, with a hold at the end: a fast drag on a busy Mac only lifts the row (P6 CI).
        garageHandle.press(forDuration: 0.5, thenDragTo: app.buttons["Reorder Kitchen"],
                           withVelocity: .slow, thenHoldForDuration: 0.5)
        app.buttons["Done"].tap()

        let garage = app.buttons["Garage, Empty"]
        XCTAssertTrue(garage.waitForExistence(timeout: 5))
        // Garage now comes first: above Kitchen, or level with it and to its left. Polled, since
        // the cards are still animating into place as the sheet closes.
        let leads = NSPredicate { _, _ in
            let g = garage.frame, k = kitchen.frame
            return g.minY < k.minY || (g.minY == k.minY && g.minX < k.minX)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: leads, object: nil)], timeout: 5),
                       .completed, "Garage should lead")
    }

    /// H-02: drag Top drawer above Counter, Done, and the Room shows the new order.
    @MainActor
    func testArrangeSpots() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let kitchen = app.buttons["Kitchen, Empty"]
        XCTAssertTrue(kitchen.waitForExistence(timeout: 10))
        kitchen.tap()
        XCTAssertTrue(app.navigationBars["Kitchen"].waitForExistence(timeout: 5))
        // Secondary actions sit behind More on compact width, in the bar on regular width.
        if !app.buttons["Arrange Spots"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Arrange Spots"].tap()

        let drawerHandle = app.buttons["Reorder Top drawer"]
        XCTAssertTrue(drawerHandle.waitForExistence(timeout: 5))
        drawerHandle.press(forDuration: 0.5, thenDragTo: app.buttons["Reorder Counter"])
        app.buttons["Done"].tap()

        let drawer = app.buttons["Top drawer"], counter = app.buttons["Counter"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 5))
        XCTAssertLessThan(drawer.frame.minY, counter.frame.minY, "Top drawer should lead")
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

        // Hardware-keyboard shortcuts are checked on iPad only (D29), as in ShellTests.
        let size = app.windows.firstMatch.frame.size
        try XCTSkipUnless(min(size.width, size.height) >= 700, "⌘E is checked on iPad (D29)")
        app.typeKey("e", modifierFlags: .command)
        XCTAssertTrue(app.navigationBars["Edit Room"].waitForExistence(timeout: 5))
    }
}
