import XCTest

extension XCUIApplication {
    /// A tab: a tab-bar button on iPhone, a sidebar cell on iPad.
    @MainActor
    func tab(_ name: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", name))
            .matching(NSPredicate(format: "elementType == %d OR elementType == %d",
                                  XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.cell.rawValue))
            .firstMatch
    }
}
