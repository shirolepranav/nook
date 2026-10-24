import XCTest

/// P11: Nook Pro (P-01, S-02, S-03; PRD §7, D58). Smoke S11 (paywall half): the 26th item
/// opens the paywall, and the item saves after the unlock. `-uiTestingPurchase` stands in
/// for the App Store sheet; purchases themselves are tested with StoreKitTest (NookTests).
final class PaywallTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The Free tier full (`atLimit`: 25 items, 3 reminders on).
    @MainActor
    private func launch(free: Bool = true, purchase: String = "success", store: String = "atLimit",
                        nudge: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: store)
        app.launchArguments += ["-uiTestingCameraFixture", "-uiTestingNotifications", "granted",
                                "-uiTestingPurchase", purchase]
        if free { app.launchArguments += ["-uiTestingFree", "YES"] }
        if nudge { app.launchArguments += ["-uiTestingDataNudge"] }
        app.launch()
        return app
    }

    @MainActor
    private func card(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    @MainActor
    private func text(_ app: XCUIApplication, containing words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// PRD §7: never on launch, even with the Free tier full.
    @MainActor
    func testPaywallNeverAppearsOnLaunch() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        sleep(2)
        XCTAssertFalse(app.buttons["Unlock Pro"].exists)
        XCTAssertFalse(text(app, containing: "You’ve documented").exists)
    }

    /// S11, D58: the 26th item opens P-01 with the user's own numbers; after the unlock the
    /// kept draft saves.
    @MainActor
    func testTwentySixthItemOpensThePaywallAndSavesAfterTheUnlock() {
        let app = launch()
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 10))
        app.buttons["Capture"].tap()
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        name.typeText("Lamp")
        app.buttons["Save"].tap()

        XCTAssertTrue(text(app, containing: "25 items worth").waitForExistence(timeout: 10))
        let unlock = app.buttons["Unlock Pro"]
        XCTAssertTrue(unlock.exists)
        XCTAssertTrue(app.buttons["Restore Purchases"].exists)
        unlock.tap()
        XCTAssertTrue(app.staticTexts["Nook & Cranny Pro is yours."].waitForExistence(timeout: 5))
        app.buttons["Save Your Item"].tap()
        XCTAssertTrue(card(app, "Lamp").waitForExistence(timeout: 10))
    }

    /// D9: a 4th warranty reminder opens P-01. Ask to Buy: waiting, with no button to press
    /// again; closing keeps the editor and its draft.
    @MainActor
    func testFourthReminderOpensThePaywallAndAskToBuyWaits() {
        let app = launch(purchase: "pending")
        let thing = card(app, "Thing 25")
        XCTAssertTrue(thing.waitForExistence(timeout: 10))
        thing.tap()
        app.buttons["Edit"].tap()
        let oneYear = app.buttons["1 yr"]
        for _ in 0..<6 where !oneYear.isHittable { app.swipeUp() }
        oneYear.tap()
        app.buttons["Save"].tap()

        let unlock = app.buttons["Unlock Pro"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        unlock.tap()
        XCTAssertTrue(text(app, containing: "Waiting for approval").waitForExistence(timeout: 5))
        XCTAssertFalse(unlock.exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5))   // still editing
    }

    /// PRD §7: Export is a moment of value. A failed purchase says so without blame and
    /// stays on P-01.
    @MainActor
    func testExportOpensThePaywallAndAFailureStays() {
        let app = launch(purchase: "failed", store: "lived")
        app.tab("Reports").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Insurance report'")).firstMatch.tap()
        app.buttons["Preview Report"].tap()
        let unlockToExport = app.buttons["Unlock Pro to Export"]
        XCTAssertTrue(unlockToExport.waitForExistence(timeout: 10))
        unlockToExport.tap()
        let unlock = app.buttons["Unlock Pro"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()
        XCTAssertTrue(text(app, containing: "you haven’t been charged").waitForExistence(timeout: 5))
        XCTAssertTrue(unlock.exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(unlockToExport.waitForExistence(timeout: 5))
    }

    /// D9, D58: Free turns sync on through P-01; after the unlock the switch is on.
    @MainActor
    func testSyncSwitchOpensThePaywallWhenFree() {
        let app = launch()
        app.tab("Settings").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'iCloud Sync'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["iCloud sync comes with Nook & Cranny Pro"].waitForExistence(timeout: 5))
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Sync with iCloud'")).firstMatch
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let unlock = app.scrollViews.buttons["Unlock Pro"]   // P-01's, not S-03's card
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()
        app.buttons["Turn On iCloud Sync"].tap()
        XCTAssertTrue(app.staticTexts["Last synced"].waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
    }

    /// D65: Home's card says where things live; Not Now hides it. Free can back up, and
    /// S-01's status line then says so.
    @MainActor
    func testDataSafetyCardAndFreeBackup() {
        let app = launch(nudge: true)
        let nudge = app.staticTexts["Your 25 things live only on this iPhone."]
        XCTAssertTrue(nudge.waitForExistence(timeout: 10))
        app.buttons["Not Now"].tap()
        XCTAssertTrue(nudge.waitForNonExistence(timeout: 5))

        app.tab("Settings").tap()
        XCTAssertTrue(text(app, containing: "Only on this iPhone").waitForExistence(timeout: 5))
        app.buttons["Backup & Restore"].tap()
        XCTAssertFalse(app.buttons["Unlock Pro to Back Up"].exists)
        app.buttons["Create Backup"].tap()
        XCTAssertTrue(app.buttons["Share Backup"].waitForExistence(timeout: 20))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(text(app, containing: "Backed up").waitForExistence(timeout: 5))
    }

    /// D65: Pro bought mid-flow (the 26th item) offers sync on Home; Turn On iCloud starts it.
    @MainActor
    func testBuyingProMidFlowOffersSyncOnHome() {
        let app = launch(nudge: true)
        XCTAssertTrue(app.buttons["Not Now"].waitForExistence(timeout: 10))
        app.buttons["Not Now"].tap()   // dismissed before; the purchase offers it once more
        app.buttons["Capture"].tap()
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        name.typeText("Lamp")
        app.buttons["Save"].tap()
        let unlock = app.buttons["Unlock Pro"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        unlock.tap()
        app.buttons["Save Your Item"].tap()

        let nudge = app.staticTexts["Your 26 things live only on this iPhone."]
        XCTAssertTrue(nudge.waitForExistence(timeout: 10))
        app.buttons["Turn On iCloud Sync"].firstMatch.tap()
        XCTAssertTrue(nudge.waitForNonExistence(timeout: 5))
        app.tab("Settings").tap()
        XCTAssertTrue(text(app, containing: "Safe in iCloud").waitForExistence(timeout: 5))
    }

    /// D65: bought from Settings, P-01's success offers sync right there.
    @MainActor
    func testBuyingProFromSettingsOffersSync() {
        let app = launch()
        app.tab("Settings").tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Unlock Pro'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let unlock = app.scrollViews.buttons["Unlock Pro"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()
        XCTAssertTrue(app.buttons["Not Now"].waitForExistence(timeout: 5))
        app.buttons["Turn On iCloud Sync"].tap()
        XCTAssertTrue(text(app, containing: "Safe in iCloud").waitForExistence(timeout: 5))
    }

    /// PRD §7: nothing entered is locked away. With the tier full, Find and delete still work.
    @MainActor
    func testFreeCanStillFindAndDelete() {
        let app = launch()
        let thing = card(app, "Thing 25")
        XCTAssertTrue(thing.waitForExistence(timeout: 10))
        thing.press(forDuration: 1)
        app.buttons["Delete"].tap()
        XCTAssertTrue(text(app, containing: "Deleted Thing 25").waitForExistence(timeout: 5))
        // Find last: its search field hides the tab bar while typing (D32).
        app.tab("Find").tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Thing 7")
        let result = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Thing 7'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
    }

    /// S-01 → S-02 for Pro: unlocked, and Restore Purchases answers with a toast.
    @MainActor
    func testProSeesTheThankYouAndRestores() {
        let app = launch(free: false, store: "small")
        app.tab("Settings").tap()
        let pro = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Nook & Cranny Pro'")).firstMatch
        XCTAssertTrue(pro.waitForExistence(timeout: 5))
        pro.tap()
        XCTAssertTrue(app.staticTexts["Nook & Cranny Pro is unlocked"].waitForExistence(timeout: 5))
        app.buttons["Restore Purchases"].tap()
        XCTAssertTrue(app.staticTexts["Nook & Cranny Pro is unlocked."].waitForExistence(timeout: 5))
    }
}
