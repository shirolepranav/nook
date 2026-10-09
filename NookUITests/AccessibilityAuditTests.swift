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
    private let suggestionBarHeight: CGFloat = 48
    /// Set once the iPad's floating tab bar has been seen: a form sheet hides its sidebar
    /// toggle, but the bar's element-less issues still come through.
    private var hasFloatingTabBar = false

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

    /// P4 screens: the Move picker (I-04) and its room page, and location history (I-05).
    @MainActor
    func testMoveScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))
        espresso.tap()

        app.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move Espresso machine"].waitForExistence(timeout: 5))
        // Audited at full height: at medium height the sheet is drawn slightly scaled, and the
        // auditor reads the List's own section header as clipped (D45).
        let grabber = app.buttons["Sheet Grabber"]   // iPad's form sheet has none (D45)
        if grabber.exists { grabber.swipeUp(); sleep(1) }
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        let garage = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "Garage, \\d+ spots?")).firstMatch
        for _ in 0..<6 where !(garage.exists && garage.isHittable) { app.collectionViews.firstMatch.swipeUp() }
        garage.tap()
        XCTAssertTrue(app.navigationBars["Garage"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Garage, Metal shelf"].tap()

        let history = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Location history")).firstMatch
        for _ in 0..<6 where !(history.exists && history.isHittable) { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.navigationBars["Location history"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
    }

    /// P5 screens: Find before typing (F-01, F-06), results with the answer card (F-02,
    /// F-03), and Filters (F-05) at full height (D45).
    @MainActor
    func testFindScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        app.tab("Find").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Quick filters"].waitForExistence(timeout: 10))   // the index is built
        app.collectionViews.firstMatch.swipeDown()   // choosing Find raises the keyboard (D32)
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        field.tap()
        field.typeText("drill\n")   // Search hides the keyboard
        XCTAssertTrue(app.otherElements["Answer"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.buttons["Filters"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
        let grabber = app.buttons["Sheet Grabber"]
        if grabber.exists { grabber.swipeUp(); sleep(1) }
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
    }

    /// P6 screens: the Capture menu (C-01), room scan (C-02), manual tagging with a tag
    /// (C-04), the receipt review (C-06), barcode entry (C-07), the sticker lines (C-08) and the
    /// camera-off notice.
    @MainActor
    func testCaptureScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "small")
        app.launchArguments += ["-uiTestingCameraFixture"]
        app.launch()
        let capture = app.buttons["Capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        // C-01 isn't audited: a medium-only sheet is drawn scaled, and the audit then calls its
        // rows clipped (D45). The Capture tests use every row.
        XCTAssertTrue(app.buttons["Scan room"].waitForExistence(timeout: 5))
        app.buttons["Scan room"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        // The coach hint shows only on a simulator's first scan; turn it on so it's always audited.
        if !app.buttons["Tips"].isSelected { app.buttons["Tips"].tap() }
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Take Photo"].tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"),
                                                                        object: done)], timeout: 10) == .completed)
        done.tap()
        let photo = app.otherElements["Photo 1"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        app.textFields["What is it?"].typeText("Toaster\n")
        XCTAssertTrue(app.buttons["Box 1, Toaster"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()
        app.buttons["Discard"].tap()

        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        XCTAssertTrue(app.buttons["Scan receipt"].waitForExistence(timeout: 5))
        app.buttons["Scan receipt"].tap()
        XCTAssertTrue(app.buttons["Date 09/14/2026"].waitForExistence(timeout: 20))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()

        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 5))
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
        app.buttons["Read from Sticker"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        let serial = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'S/N'")).firstMatch
        XCTAssertTrue(serial.waitForExistence(timeout: 20))   // a lazy List: rows below the fold aren't there
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.navigationBars["Serial Number"].buttons["Cancel"].tap()
        app.terminate()

        let off = XCUIApplication.nook(store: "small")
        off.launchArguments += ["-uiTestingCameraDenied"]
        off.launch()
        XCTAssertTrue(off.buttons["Capture"].waitForExistence(timeout: 10))
        off.buttons["Capture"].tap()
        XCTAssertTrue(off.buttons["Scan room"].waitForExistence(timeout: 5))
        off.buttons["Scan room"].tap()
        XCTAssertTrue(off.staticTexts["Camera is off for Nook"].waitForExistence(timeout: 5))
        try off.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, off) }
        off.buttons["Cancel"].tap()
        XCTAssertTrue(off.buttons["Capture"].waitForExistence(timeout: 5))
        off.buttons["Capture"].tap()
        XCTAssertTrue(off.buttons["Scan barcode"].waitForExistence(timeout: 5))
        off.buttons["Scan barcode"].tap()
        XCTAssertTrue(off.textFields["Barcode"].waitForExistence(timeout: 5))
        try off.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, off) }
    }

    /// P7 screens: Home's warranty row, I-01's Lent out and Warranty cards, I-06, R-01, R-04,
    /// R-05 and S-07.
    @MainActor
    func testWarrantyAndLendingScreensPassTheAccessibilityAudit() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launchArguments += ["-uiTestingNotifications", "granted"]
        app.launch()
        let garage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Garage,")).firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        app.swipeUp()
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.swipeDown()
        garage.tap()
        let drill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cordless drill,")).firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: 5))
        drill.tap()
        XCTAssertTrue(app.buttons["Mark Returned"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.swipeUp()
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.buttons["Edit loan"].tap()
        XCTAssertTrue(app.textFields["Who has it?"].waitForExistence(timeout: 5))
        // At the medium detent the audit draws the sheet scaled and calls it clipped, and reads
        // the screen behind it as text with no element (D45). Keyboard away first: dragging
        // the sheet to dismiss it would also lower it again.
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists { keyboard.buttons.matching(NSPredicate(format: "label ==[c] 'done'")).firstMatch.tap() }
        let grabber = app.buttons["Sheet Grabber"]
        if grabber.exists { grabber.swipeUp(); sleep(1) }
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.buttons["Cancel"].tap()

        app.tab("Reports").tap()
        let warranties = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Warranties'")).firstMatch
        XCTAssertTrue(warranties.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        warranties.tap()
        XCTAssertTrue(app.navigationBars["Warranties"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lent out'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Lent out"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }

        app.tab("Settings").tap()
        app.buttons["Notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits) { self.isInSystemTabBar($0, app) }
    }

    /// iPad's floating tab bar is UIKit chrome with fixed-size labels (it offers the Large
    /// Content Viewer instead of growing), so the audit's Dynamic Type check flags its labels,
    /// 3 per screen, with no element it can resolve. Once rooms exist (P2), its Rooms group adds
    /// element-detection issues the same way: room names UIKit draws itself, again with no
    /// element. With items (P3), its room labels add element-less clipped-text issues too. Only those are skipped, and only while the floating bar (its sidebar toggle) is
    /// on screen, plus the Dynamic Type check on navigation bar buttons (a sheet's Cancel, Done
    /// and Save are UIKit bar buttons with the same fixed-size labels). Nook's own text is
    /// SwiftUI, always has an element, and is still audited.
    @MainActor
    private func isInSystemTabBar(_ issue: XCUIAccessibilityAuditIssue, _ app: XCUIApplication) -> Bool {
        // The keyboard's own keys and suggestions are system chrome. Its suggestion bar sits just
        // above the keys, outside the keyboard's frame (the iOS 27 simulator's default keyboards).
        let keyboard = app.keyboards.firstMatch
        if let element = issue.element, keyboard.exists,
           keyboard.frame.insetBy(dx: 0, dy: -suggestionBarHeight).offsetBy(dx: 0, dy: -suggestionBarHeight / 2)
               .union(keyboard.frame).contains(element.frame) { return true }
        // A compact date picker is a system control that draws its own date text (P7: I-02,
        // I-06, S-07); the audit can't see that text and calls it inaccessible, sometimes with
        // the picker as the element and sometimes with none.
        if issue.element == nil, issue.auditType == .elementDetection, app.datePickers.count > 0 { return true }
        if let element = issue.element,
           app.datePickers.allElementsBoundByIndex.contains(where: { $0.frame.intersects(element.frame) }) { return true }
        // The audit enlarges the text but doesn't scroll, so List content pushed past the fold
        // reads as "clipped" or "partially unsupported" (P7: Settings' lower rows, R-04's last
        // header, S-07, Find). Lists scroll; the AX5 screenshots show this text growing; and
        // policy-check.sh rejects fixed font sizes (D51).
        if [.dynamicType, .textClipped].contains(issue.auditType), let element = issue.element,
           app.collectionViews.allElementsBoundByIndex.contains(where: { $0.frame.contains(element.frame) }) { return true }
        // A one-line text or search field scrolls its text sideways rather than losing it.
        if issue.auditType == .textClipped,
           [.textField, .searchField].contains(issue.element?.elementType) { return true }
        if app.buttons["ToggleSideBar"].exists { hasFloatingTabBar = true }
        guard let element = issue.element else {
            return [.dynamicType, .elementDetection, .textClipped].contains(issue.auditType) && hasFloatingTabBar
        }
        guard issue.auditType == .dynamicType else { return false }
        return app.navigationBars.buttons.allElementsBoundByIndex.contains { $0.frame == element.frame }
    }
}
