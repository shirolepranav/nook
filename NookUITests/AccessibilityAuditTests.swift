import XCTest

/// Accessibility audits (05 §5) with Xcode's built-in auditor: element labels, hit regions,
/// Dynamic Type clipping and traits on each screen. D33: this replaces the manual Accessibility
/// Inspector pass for P1 and runs in CI from now on.
///
/// Contrast is left out: the auditor samples rendered pixels, anti-aliased edges included, and
/// flagged `textSecondary` on `surface` (6.2:1 by the WCAG formula) as failing.
/// `design/tools/check_tokens.py` proves every allowed text and background pair exactly
/// (4.5:1, 7:1 in High Contrast) in CI instead.
final class AccessibilityAuditTests: XCTestCase {
    private let audits = XCUIAccessibilityAuditType.all.subtracting(.contrast)

    @MainActor
    func testScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.tab("Reports").tap()
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.tab("Settings").tap()
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.buttons["Appearance"].tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
    }

    /// iPad's floating tab bar is UIKit chrome with fixed-size labels (it offers the Large
    /// Content Viewer instead of growing), so the audit's Dynamic Type check flags its labels,
    /// 3 per screen, with no element it can resolve. Only those are skipped: Dynamic Type issues
    /// without an element while the floating bar (its sidebar toggle) is on screen. Nook's own
    /// text is SwiftUI, always has an element, and is still audited.
    @MainActor
    private func isInSystemTabBar(_ issue: XCUIAccessibilityAuditIssue, _ app: XCUIApplication) -> Bool {
        issue.auditType == .dynamicType && issue.element == nil && app.buttons["ToggleSideBar"].exists
    }
}
