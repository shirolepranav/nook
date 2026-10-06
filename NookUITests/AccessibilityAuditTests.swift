import XCTest

/// Accessibility audits (05 §5) with Xcode's built-in auditor: contrast, element labels,
/// hit regions, Dynamic Type clipping and traits on each screen. D33: this replaces the manual
/// Accessibility Inspector pass for P1 and runs in CI from now on.
final class AccessibilityAuditTests: XCTestCase {
    @MainActor
    func testScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()

        app.tab("Reports").tap()
        try app.performAccessibilityAudit()

        app.tab("Settings").tap()
        try app.performAccessibilityAudit()

        app.buttons["Appearance"].tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }
}
