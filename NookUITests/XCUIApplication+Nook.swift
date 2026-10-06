import XCTest

extension XCUIApplication {
    /// The app with a fresh in-memory store (`empty` or `small`), past onboarding unless asked.
    @MainActor
    static func nook(store: String = "empty", onboarded: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingStore", store, "-uiTestingOnboarded", onboarded ? "YES" : "NO"]
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
