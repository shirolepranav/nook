import XCTest

/// P10: the insurance report (R-02), CSV (R-03), Backup & Restore (S-04) and box labels
/// (H-06, F8). Smoke S10: a report is made; a label's link opens its container.
final class ReportsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(free: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        if free { app.launchArguments += ["-uiTestingFree", "YES"] }
        app.launch()
        return app
    }

    @MainActor
    private func card(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// R-01 → R-02 → Preview → Create Report: the PDF opens in Quick Look (S10, first half).
    @MainActor
    func testInsuranceReportOpensInQuickLook() {
        let app = launch()
        app.tab("Reports").tap()
        card(app, "Insurance report").tap()
        app.buttons["Preview Report"].tap()
        let page = app.descendants(matching: .any)["Report page 1 of 3"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        app.buttons["Create Report"].tap()
        // Quick Look's title is the report's file name (a text or, with its menu, a button).
        let title = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Home inventory'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30))
    }

    /// PRD §7: Free sees the first page marked PREVIEW and Unlock Pro, never an export.
    @MainActor
    func testFreeSeesAWatermarkedPreviewOnly() {
        let app = launch(free: true)
        app.tab("Reports").tap()
        card(app, "Insurance report").tap()
        app.buttons["Preview Report"].tap()
        XCTAssertTrue(app.buttons["Unlock Pro to Export"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Create Report"].exists)
    }

    /// R-03: the row count and Share.
    @MainActor
    func testCSVExportIsReadyToShare() {
        let app = launch()
        app.tab("Reports").tap()
        card(app, "Export CSV").tap()
        XCTAssertTrue(app.staticTexts["14 items · 24 columns · all fields"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save to Files"].exists)
    }

    /// S-04: Create Backup makes the file, then offers Share and Save to Files.
    @MainActor
    func testCreateBackup() {
        let app = launch()
        app.tab("Settings").tap()
        app.buttons["Backup & Restore"].tap()
        app.buttons["Create Backup"].tap()
        XCTAssertTrue(app.buttons["Share Backup"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Save to Files"].exists)
    }

    /// H-06 from a container's menu.
    @MainActor
    func testBoxLabelFromAContainer() {
        let app = launch()
        app.open(URL(string: "nook://spot/lived-box-14")!)
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Print or Share Label"].tap()
        XCTAssertTrue(app.buttons["Print"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].exists && app.buttons["Save Image"].exists)
    }

    /// S10 (second half), F8: a label's link opens its container, as the Camera app would.
    @MainActor
    func testLabelLinkOpensTheContainer() {
        let app = launch()
        app.open(URL(string: "nook://spot/lived-box-14")!)
        XCTAssertTrue(app.staticTexts["Box 14"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Camping tent'"))
            .firstMatch.waitForExistence(timeout: 5))
    }
}
