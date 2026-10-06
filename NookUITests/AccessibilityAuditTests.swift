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
        let app = XCUIApplication.nook()
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

    /// P2 screens: onboarding (O-01, O-02), Home with rooms, Room, Spot, the Room editor and
    /// Arrange Spots (H-01 to H-04, H-07).
    @MainActor
    func testRoomScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let onboarding = XCUIApplication.nook(onboarded: false)
        onboarding.launch()
        XCTAssertTrue(onboarding.buttons["Get Started"].waitForExistence(timeout: 10))
        try onboarding.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, onboarding) }
        onboarding.buttons["Get Started"].tap()
        XCTAssertTrue(onboarding.buttons["Continue with 4 rooms"].waitForExistence(timeout: 5))
        try onboarding.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, onboarding) }
        onboarding.terminate()

        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let kitchen = app.buttons["Kitchen, Empty"]
        XCTAssertTrue(kitchen.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        kitchen.tap()
        XCTAssertTrue(app.navigationBars["Kitchen"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        if !app.buttons["Arrange Spots"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Arrange Spots"].tap()
        XCTAssertTrue(app.navigationBars["Arrange Spots"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()

        if !app.buttons["Edit Room"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Edit Room"].tap()
        XCTAssertTrue(app.navigationBars["Edit Room"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()

        app.buttons["Counter"].tap()
        XCTAssertTrue(app.navigationBars["Counter"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
    }

    /// P3 screens: items on Home and Room, item detail (I-01), the editor (I-02), selection
    /// (I-08) and Recently Deleted (S-08).
    @MainActor
    func testItemScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.navigationBars["Kitchen"].buttons["More"].tap()
        app.buttons["Select"].tap()
        espresso.tap()
        XCTAssertTrue(app.navigationBars["1 Selected"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()

        espresso.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()

        app.tab("Settings").tap()
        app.buttons["Recently Deleted"].tap()
        XCTAssertTrue(app.staticTexts["Nothing deleted."].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
    }

    /// iPad's floating tab bar is UIKit chrome with fixed-size labels (it offers the Large
    /// Content Viewer instead of growing), so the audit's Dynamic Type check flags its labels,
    /// 3 per screen, with no element it can resolve. Once rooms exist (P2), its Rooms group adds
    /// element-detection issues the same way: room names UIKit draws itself, again with no
    /// element. Only those are skipped, and only while the floating bar (its sidebar toggle) is
    /// on screen, plus the Dynamic Type check on navigation bar buttons (a sheet's Cancel, Done
    /// and Save are UIKit bar buttons with the same fixed-size labels). Nook's own text is
    /// SwiftUI, always has an element, and is still audited.
    @MainActor
    private func isInSystemTabBar(_ issue: XCUIAccessibilityAuditIssue, _ app: XCUIApplication) -> Bool {
        guard let element = issue.element else {
            return [.dynamicType, .elementDetection].contains(issue.auditType) && app.buttons["ToggleSideBar"].exists
        }
        guard issue.auditType == .dynamicType else { return false }
        return app.navigationBars.buttons.allElementsBoundByIndex.contains { $0.frame == element.frame }
    }
}
