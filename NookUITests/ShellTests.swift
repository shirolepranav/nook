import XCTest

/// Smoke S1 (roadmap): cold launch to Home, the four tabs and the Capture button; the
/// sidebar on regular width; ⌘1–⌘4 switch tabs. Runs on iPhone SE and the 13-inch iPad.
final class ShellTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launch()
    }

    /// A tab is a tab-bar button on iPhone and a sidebar cell on iPad.
    @MainActor
    private func tab(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name))
            .matching(NSPredicate(format: "elementType == %d OR elementType == %d",
                                  XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.cell.rawValue))
            .firstMatch
    }

    @MainActor
    private var isRegularWidth: Bool { app.windows.firstMatch.frame.width >= 700 }

    @MainActor
    func testLaunchesToHomeWithTabsAndCapture() {
        launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Capture"].exists)
        for name in ["Home", "Find", "Reports", "Settings"] {
            XCTAssertTrue(tab(name).exists, "\(name) tab missing")
        }
    }

    @MainActor
    func testTabsSwitchByTapping() {
        launch()
        for name in ["Reports", "Settings", "Home"] {
            tab(name).tap()
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), name)
        }
    }

    @MainActor
    func testCaptureOpensTheCaptureMenu() {
        launch()
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.staticTexts["Capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Scan barcode"].exists)   // all four rows fit (01 C-01)
    }

    @MainActor
    func testFindShowsCaptureOnlyOnRegularWidth() {
        launch()
        // D32: on compact width the search field sits at the bottom where Capture would go.
        tab("Find").tap()
        // Choosing Find activates its search field (D32: .searchTabSelection).
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Capture"].exists, isRegularWidth)
    }

    @MainActor
    func testRegularWidthShowsTheSidebar() throws {
        launch()
        try XCTSkipUnless(isRegularWidth, "compact width has a tab bar")
        // P0b boards: landscape shows the sidebar; portrait floats the tab bar at the top.
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let toggle = app.buttons["ToggleSidebar"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Hide Sidebar")
    }

    @MainActor
    func testCommandNumberKeysSwitchTabs() throws {
        launch()
        try XCTSkipUnless(isRegularWidth, "hardware-keyboard shortcuts are checked on iPad (D29)")
        for (key, name) in [("2", "Find"), ("3", "Reports"), ("4", "Settings"), ("1", "Home")] {
            app.typeKey(key, modifierFlags: .command)
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), "⌘\(key) → \(name)")
        }
    }
}
