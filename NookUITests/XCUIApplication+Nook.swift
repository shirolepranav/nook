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
}
