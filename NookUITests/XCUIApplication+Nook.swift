import XCTest

extension XCUIApplication {
    /// The app with a fresh in-memory store (`empty` or `small`), past onboarding unless asked.
    /// Classic unless asked: the simulator can borrow the Mac's Apple Intelligence, and tests
    /// shouldn't depend on it (05 §6). AI-path tests pass `-uiTestingFakeAI` instead (D53).
    @MainActor
    static func nook(store: String = "empty", onboarded: Bool = true, classic: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingStore", store, "-uiTestingOnboarded", onboarded ? "YES" : "NO"]
        if classic { app.launchArguments += ["-forceClassicEngine", "YES"] }
        return app
    }

    /// A tab: a tab-bar button on iPhone, a sidebar cell on iPad.
    @MainActor
    func tab(_ name: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", name))
            .matching(NSPredicate(format: "elementType == %d OR elementType == %d",
                                  XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.cell.rawValue))
            .firstMatch
    }

    /// A Settings row (its label starts with `name`; some carry a detail), scrolled into view first: since P11 the Pro card and Privacy push the
    /// lower rows off the iPhone SE's screen (D58).
    @MainActor
    func settingsRow(_ name: String) -> XCUIElement {
        let row = buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        // Wait for each scroll to land: since P12's Face ID Lock row, the last rows can still
        // be loading after a quick swipe.
        for _ in 0..<6 where !(row.waitForExistence(timeout: 1) && row.isHittable) { swipeUp() }
        return row
    }
}
