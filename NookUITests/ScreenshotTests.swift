import XCTest

/// Screenshots of each screen a phase touches, for its PR and QA report (02 Definition of
/// Done). Opt-in; set the simulator's appearance and text size first, then:
/// TEST_RUNNER_RUN_SCREENSHOTS=1 xcodebuild test -only-testing:NookUITests/ScreenshotTests …
/// and export the attachments from the result bundle.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testP2Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let onboarding = XCUIApplication.nook(onboarded: false)
        onboarding.launch()
        XCTAssertTrue(onboarding.buttons["Get Started"].waitForExistence(timeout: 10))
        snap("O-01 Welcome")
        onboarding.buttons["Get Started"].tap()
        XCTAssertTrue(onboarding.buttons["Continue with 4 rooms"].waitForExistence(timeout: 5))
        snap("O-02 Pick your rooms")
        onboarding.terminate()

        let app = XCUIApplication.nook(store: "small")
        app.launch()
        let kitchen = app.buttons["Kitchen, Empty"]
        XCTAssertTrue(kitchen.waitForExistence(timeout: 10))
        snap("H-01 Home")

        kitchen.tap()
        XCTAssertTrue(app.navigationBars["Kitchen"].waitForExistence(timeout: 5))
        snap("H-02 Room")

        if !app.buttons["Edit Room"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Edit Room"].tap()
        XCTAssertTrue(app.navigationBars["Edit Room"].waitForExistence(timeout: 5))
        snap("H-04 Room editor")
        app.buttons["Cancel"].tap()

        if !app.buttons["Arrange Spots"].exists { app.navigationBars["Kitchen"].buttons["More"].tap() }
        app.buttons["Arrange Spots"].tap()
        XCTAssertTrue(app.navigationBars["Arrange Spots"].waitForExistence(timeout: 5))
        snap("H-07 Arrange spots")
        app.buttons["Cancel"].tap()

        app.buttons["Counter"].tap()
        XCTAssertTrue(app.navigationBars["Counter"].waitForExistence(timeout: 5))
        snap("H-03 Spot")
        app.buttons["Add container"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
        snap("H-05 Container editor")
    }

    @MainActor
    func testP3Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launchArguments += ["-uiTestingCameraFixture"]
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        snap("H-01 Home with items")

        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))
        snap("H-02 Room with items")

        app.navigationBars["Kitchen"].buttons["More"].tap()
        app.buttons["Select"].tap()
        espresso.tap()
        snap("I-08 Multi-select")
        app.buttons["Cancel"].tap()

        espresso.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        snap("I-01 Item detail")
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        snap("I-02 Item editor")
        app.buttons["Cancel"].tap()

        app.buttons["Photo 1 of 1. Open photo viewer"].tap()
        snap("I-03 Photo viewer")
        app.buttons["Close"].tap()

        app.tab("Settings").tap()
        app.settingsRow("Recently Deleted").tap()
        snap("S-08 Recently Deleted (empty)")
    }

    @MainActor
    func testP4Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 15))
        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))

        app.navigationBars["Kitchen"].buttons["More"].tap()
        app.buttons["Select"].tap()
        espresso.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stand mixer,")).firstMatch.tap()
        app.toolbars.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move 2 Items"].waitForExistence(timeout: 5))
        snap("I-04 Move picker, 2 items")
        app.navigationBars["Move 2 Items"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Move 2 Items"].waitForNonExistence(timeout: 5))
        app.buttons["Cancel"].tap()   // ends selection

        espresso.tap()
        XCTAssertTrue(app.buttons["Move"].waitForExistence(timeout: 5))
        app.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move Espresso machine"].waitForExistence(timeout: 5))
        snap("I-04 Move picker")
        app.collectionViews.buttons.firstMatch.tap()
        snap("I-04 Moved, with Undo")

        let history = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Location history")).firstMatch
        for _ in 0..<6 where !(history.exists && history.isHittable) { app.swipeUp() }
        history.tap()
        XCTAssertTrue(app.navigationBars["Location history"].waitForExistence(timeout: 5))
        snap("I-05 Location history")
    }

    @MainActor
    func testP5Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        let app = XCUIApplication.nook(store: "lived")
        app.launch()
        app.tab("Find").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Quick filters"].waitForExistence(timeout: 10))
        // Save a search first, so the start screen shows every section.
        app.buttons["Filters"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 5))
        app.buttons["Garage"].tap()
        snap("F-05 Filters")
        app.buttons["Save Search"].tap()
        app.alerts.textFields.firstMatch.typeText("Garage stuff")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Remove filter: Garage"].waitForExistence(timeout: 5))
        snap("F-02 Filtered results")
        app.buttons["Remove filter: Garage"].tap()
        snap("F-01 Find")

        let questions = [("pasport", "F-02 Results, private masked"), ("skilet", "F-03 Answer, typo"),
                         ("Who has my drill?", "F-03 Lent"), ("Where’s the camping tent?", "F-03 Packed"),
                         ("What’s in the garage?", "F-03 Contents"), ("Do I have any AA batteries?", "F-03 Quantity"),
                         ("skis", "F-02 No results")]
        for (text, name) in questions {
            field.tap()
            if let current = field.value as? String, !current.isEmpty, field.buttons["Clear text"].exists {
                field.buttons["Clear text"].tap()
                field.tap()   // clearing drops the field's focus on iPad
            }
            field.typeText(text)
            sleep(1)
            snap(name)
        }
    }

    @MainActor
    func testP6Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        let app = XCUIApplication.nook(store: "small")
        app.launchArguments += ["-uiTestingCameraFixture"]
        app.launch()
        let capture = app.buttons["Capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        app.buttons["Kitchen, Empty"].tap()
        capture.tap()
        XCTAssertTrue(app.buttons["Scan room"].waitForExistence(timeout: 5))
        snap("C-01 Capture menu")
        app.buttons["Scan room"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        snap("C-02 Room scan")
        app.buttons["Done"].tap()
        let photo = app.otherElements["Photo 1"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        for (index, name) in ["Toaster", "Blender", "Kettle"].enumerated() {
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.2 + 0.3 * Double(index), dy: 0.5)).tap()
            XCTAssertTrue(app.textFields["What is it?"].waitForExistence(timeout: 10))
            if index == 2 { app.textFields["What is it?"].typeText("Ket"); snap("C-04 Naming") }
            app.textFields["What is it?"].typeText(index == 2 ? "tle\n" : name + "\n")
        }
        snap("C-04 Manual tagging")
        app.buttons["Save 3 Items"].tap()
        snap("C-04 Saved toast")
        // On compact the toast sits over the Capture button until it goes.
        XCTAssertTrue(app.staticTexts["3 items saved to Kitchen."].waitForNonExistence(timeout: 10))

        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        XCTAssertTrue(app.buttons["Scan receipt"].waitForExistence(timeout: 5))
        app.buttons["Scan receipt"].tap()
        XCTAssertTrue(app.buttons["Date 09/14/2026"].waitForExistence(timeout: 20))
        snap("C-06 Receipt review")
        app.buttons["Date 09/14/2026"].tap()
        app.buttons["Amount $766.41"].tap()
        snap("C-06 Receipt filled")
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
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'S/N'")).firstMatch
            .waitForExistence(timeout: 20))
        snap("C-08 Sticker lines")
        app.navigationBars["Serial Number"].buttons["Cancel"].tap()
        app.terminate()

        let off = XCUIApplication.nook(store: "small")
        off.launchArguments += ["-uiTestingCameraDenied"]
        off.launch()
        XCTAssertTrue(off.buttons["Capture"].waitForExistence(timeout: 10))
        off.buttons["Capture"].tap()
        XCTAssertTrue(off.buttons["Scan room"].waitForExistence(timeout: 5))
        off.buttons["Scan room"].tap()
        XCTAssertTrue(off.staticTexts["Camera is off for Nook & Cranny"].waitForExistence(timeout: 5))
        snap("C-02 Camera off")
        off.buttons["Cancel"].tap()
        XCTAssertTrue(off.buttons["Capture"].waitForExistence(timeout: 5))
        off.buttons["Capture"].tap()
        XCTAssertTrue(off.buttons["Scan barcode"].waitForExistence(timeout: 5))
        off.buttons["Scan barcode"].tap()
        XCTAssertTrue(off.textFields["Barcode"].waitForExistence(timeout: 5))
        snap("C-07 Type it")
    }

    @MainActor
    func testP7Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launchArguments += ["-uiTestingNotifications", "granted"]
        app.launch()
        let garage = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Garage,")).firstMatch
        XCTAssertTrue(garage.waitForExistence(timeout: 15))
        // Short drags, so the row sits mid-screen rather than under the bar (and at AX5, where
        // the room cards fill the screen).
        let header = app.staticTexts["Warranties ending soon"]
        for _ in 0..<12 where !(header.isHittable && header.frame.midY < app.frame.midY) { shortDrag(app) }
        snap("H-01 Warranties ending soon")
        for _ in 0..<12 where !garage.isHittable { app.swipeDown() }
        for _ in 0..<12 where !garage.isHittable { shortDrag(app) }

        garage.tap()
        let drill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cordless drill,")).firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: 5))
        for _ in 0..<12 where !drill.isHittable { shortDrag(app) }
        drill.tap()
        XCTAssertTrue(app.buttons["Mark Returned"].waitForExistence(timeout: 5))
        for _ in 0..<12 where !app.buttons["Mark Returned"].isHittable { shortDrag(app) }
        snap("I-01 Lent out")
        let warranty = app.staticTexts["Warranty"]
        for _ in 0..<12 where !(warranty.exists && warranty.isHittable) { shortDrag(app) }
        snap("I-01 Warranty")
        for _ in 0..<12 where !app.buttons["Edit loan"].isHittable { app.swipeDown() }
        app.buttons["Edit loan"].tap()
        XCTAssertTrue(app.textFields["Who has it?"].waitForExistence(timeout: 5))
        snap("I-06 Lend")
        app.buttons["Cancel"].tap()
        app.buttons["Edit"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        let other = app.buttons["Other"]
        for _ in 0..<6 where !other.isHittable { app.swipeUp() }
        snap("I-02 Warranty")
        app.buttons["Cancel"].tap()

        app.tab("Reports").tap()
        let warranties = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Warranties'")).firstMatch
        XCTAssertTrue(warranties.waitForExistence(timeout: 5))
        snap("R-01 Reports")
        warranties.tap()
        XCTAssertTrue(app.navigationBars["Warranties"].waitForExistence(timeout: 5))
        snap("R-04 Warranties")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lent out'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Lent out"].waitForExistence(timeout: 5))
        snap("R-05 Lent out")
        app.tab("Settings").tap()
        app.settingsRow("Notifications").tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        snap("S-07 Notifications")
        app.terminate()

        let empty = XCUIApplication.nook(store: "small")
        empty.launchArguments += ["-uiTestingNotifications", "denied"]
        empty.launch()
        empty.tab("Reports").tap()
        empty.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Warranties'")).firstMatch.tap()
        XCTAssertTrue(empty.staticTexts["No warranties yet."].waitForExistence(timeout: 5))
        snap("R-04 Empty")
        empty.navigationBars.buttons.firstMatch.tap()
        empty.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lent out'")).firstMatch.tap()
        XCTAssertTrue(empty.staticTexts["Nothing’s out right now."].waitForExistence(timeout: 5))
        snap("R-05 Empty")
        empty.tab("Settings").tap()
        empty.settingsRow("Notifications").tap()
        XCTAssertTrue(empty.staticTexts["Reminders are off for Nook & Cranny"].waitForExistence(timeout: 5))
        snap("S-07 Denied")
    }

    /// Half a screen, slower than a swipe, so it doesn't fling past what it's looking for.
    @MainActor
    private func shortDrag(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
    }

    @MainActor
    func testP8Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "small", classic: false)
        app.launchArguments += ["-uiTestingCameraFixture", "-uiTestingFakeAI", "items"]
        app.launch()
        let capture = app.buttons["Capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        XCTAssertTrue(app.buttons["Scan room"].waitForExistence(timeout: 5))
        app.buttons["Scan room"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"),
                                                                        object: done)], timeout: 10) == .completed)
        done.tap()
        XCTAssertTrue(app.staticTexts["Looking for items… 2 so far"].waitForExistence(timeout: 10)
                      || app.staticTexts["6 suggestions"].exists)
        snap("C-03 Scan review, streaming")
        XCTAssertTrue(app.staticTexts["6 suggestions"].waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Toaster,'")).firstMatch.buttons.firstMatch.tap()
        snap("C-03 Scan review")
        app.buttons["Cancel"].tap()
        app.buttons["Discard"].tap()

        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        XCTAssertTrue(app.staticTexts["Suggested"].waitForExistence(timeout: 10))
        snap("C-05 Quick add, prefilled")
        app.buttons["Cancel"].tap()
        app.buttons["Discard Changes"].tap()

        app.tab("Settings").tap()
        let row = app.settingsRow("Apple Intelligence")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        snap("S-01 Settings")
        if !row.isHittable { app.swipeUp() }   // below the fold at AX5
        row.tap()
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        snap("S-11 Apple Intelligence")
    }

    @MainActor
    func testP9Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived", classic: false)
        app.launchArguments += ["-uiTestingCameraFixture", "-uiTestingFakeAI", "items"]
        app.launch()
        app.tab("Find").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Winter coat")   // the index builds after launch
        XCTAssertTrue(app.otherElements["Answer"].waitForExistence(timeout: 10))
        field.buttons["Clear text"].tap()
        field.tap()   // iPad drops focus on Clear
        field.typeText("I put the winter coat in the blue bin\n")
        XCTAssertTrue(app.buttons["Not Now"].waitForExistence(timeout: 10))
        snap("F-04 Move confirmation")
        app.buttons["Not Now"].tap()
        field.buttons["Clear text"].tap()
        field.tap()   // iPad drops focus on Clear
        field.typeText("Where are the appliances?")
        XCTAssertTrue(app.staticTexts["Which one?"].waitForExistence(timeout: 10))
        snap("F-03 Which one?")
        field.buttons["Clear text"].tap()
        field.tap()   // iPad drops focus on Clear
        field.typeText("Winter coat")
        let open = app.buttons["Open Winter coat"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        app.buttons["Edit"].tap()
        let value = app.textFields["Lowest value"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        for _ in 0..<6 where !value.isHittable { app.swipeUp() }
        let store = app.textFields["Store"]   // the whole well in view: the field under it shows
        for _ in 0..<3 where !(store.exists && store.isHittable) { shortDrag(app) }
        snap("I-02 Value estimate, suggested")
        app.buttons["Save"].tap()
        let today = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Value today")).firstMatch
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
        for _ in 0..<8 where !(today.exists && today.isHittable) { app.swipeUp() }
        snap("I-01 Value today")

        app.tab("Home").tap()
        let capture = app.buttons["Capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        XCTAssertTrue(app.buttons["Scan receipt"].waitForExistence(timeout: 5))
        app.buttons["Scan receipt"].tap()
        XCTAssertTrue(app.staticTexts["Suggested"].waitForExistence(timeout: 20))
        snap("C-06 Receipt, suggested")
    }

    @MainActor
    func testP10Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived", classic: false)
        app.launchArguments += ["-uiTestingFakeAI", "items"]
        app.launch()
        app.tab("Reports").tap()
        let report = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Insurance report'")).firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 10))
        snap("R-01 Reports")
        report.tap()
        let summaries = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Room summaries'")).firstMatch
        XCTAssertTrue(summaries.waitForExistence(timeout: 5))
        for _ in 0..<3 where !summaries.isHittable { app.swipeUp() }
        snap("R-02 Insurance report")
        summaries.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()   // the switch itself
        XCTAssertTrue(app.staticTexts["Suggested"].firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<2 { app.swipeUp() }
        snap("R-02 Room summaries, suggested")
        app.buttons["Preview Report"].tap()
        XCTAssertTrue(app.buttons["Create Report"].waitForExistence(timeout: 10))
        snap("R-02 Preview")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Export CSV'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))
        snap("R-03 CSV export")
        app.buttons["Cancel"].tap()
        app.tab("Settings").tap()
        app.buttons["Backup & Restore"].tap()
        XCTAssertTrue(app.buttons["Create Backup"].waitForExistence(timeout: 5))
        snap("S-04 Backup & Restore")
        app.open(URL(string: "nook://spot/lived-box-14")!)
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Print or Share Label"].tap()
        XCTAssertTrue(app.buttons["Print"].waitForExistence(timeout: 5))
        snap("H-06 Box label")
    }

    @MainActor
    func testP11Screens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "atLimit")
        app.launchArguments += ["-uiTestingFree", "YES", "-uiTestingPurchase", "success"]
        app.launch()
        app.tab("Settings").tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Unlock Pro,'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        snap("S-01 Settings, Free")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'iCloud Sync'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["iCloud sync comes with Nook & Cranny Pro"].waitForExistence(timeout: 5))
        snap("S-03 iCloud Sync, Free")
        app.navigationBars.buttons.firstMatch.tap()
        card.tap()
        let unlock = app.buttons["Unlock Pro"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        snap("P-01 Paywall")
        unlock.tap()
        XCTAssertTrue(app.staticTexts["Nook & Cranny Pro is yours."].waitForExistence(timeout: 5))
        snap("P-01 Paywall, success")
        app.buttons["Done"].tap()
        let thanks = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Nook & Cranny Pro,'")).firstMatch
        XCTAssertTrue(thanks.waitForExistence(timeout: 5))
        snap("S-01 Settings, Pro")
        thanks.tap()
        XCTAssertTrue(app.staticTexts["Nook & Cranny Pro is unlocked"].waitForExistence(timeout: 5))
        snap("S-02 Nook Pro")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'iCloud Sync'")).firstMatch.tap()
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Sync with iCloud'")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Last synced"].waitForExistence(timeout: 5))
        snap("S-03 iCloud Sync, on")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Privacy"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        snap("S-09 Privacy")
    }

    /// App Store screenshots (D63, docs/release/app-store.md §5): the 6.9" iPhone and 13" iPad
    /// sets, in this order. TEST_RUNNER_SHOWCASE_PHOTOS=<folder> swaps the swatches for real
    /// photos named after the items ("Espresso machine.jpg"); without it the set is for layout.
    @MainActor
    func testAppStoreScreens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_RUN_SCREENSHOTS=1")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        // US English and dollars for the en-US listing, whatever the simulator's region.
        app.launchArguments += ["-uiTestingCameraFixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if let photos = ProcessInfo.processInfo.environment["SHOWCASE_PHOTOS"] {
            app.launchArguments += ["-uiTestingShowcasePhotos", photos]
        }
        app.launch()
        let kitchen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kitchen,")).firstMatch
        XCTAssertTrue(kitchen.waitForExistence(timeout: 10))
        snap("1 Home")

        kitchen.tap()
        let espresso = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Espresso machine,")).firstMatch
        XCTAssertTrue(espresso.waitForExistence(timeout: 5))
        snap("2 Room")
        espresso.tap()
        XCTAssertTrue(app.buttons["Move"].waitForExistence(timeout: 5))
        snap("3 Item detail")

        app.tab("Find").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Where is the espresso machine?\n")   // submitting puts the keyboard away
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Counter'")).firstMatch
            .waitForExistence(timeout: 10))
        snap("4 Find answer")

        // On iPad, Find's active search hides the tab bar; ⌘1 works there.
        if app.tab("Home").exists { app.tab("Home").tap() } else { app.typeKey("1", modifierFlags: .command) }
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["Scan room"].waitForExistence(timeout: 5))
        app.buttons["Scan room"].tap()
        XCTAssertTrue(app.buttons["Take Photo"].waitForExistence(timeout: 5))
        app.buttons["Take Photo"].tap()
        app.buttons["Done"].tap()
        let photo = app.otherElements["Photo 1"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        for (index, name) in ["Toaster", "Kettle", "Blender"].enumerated() {
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.2 + 0.3 * Double(index), dy: 0.5)).tap()
            XCTAssertTrue(app.textFields["What is it?"].waitForExistence(timeout: 10))
            app.textFields["What is it?"].typeText(name + "\n")
        }
        snap("5 Scan tagging")
        app.buttons["Cancel"].tap()
        if app.buttons["Discard"].waitForExistence(timeout: 3) { app.buttons["Discard"].tap() }

        let report = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Insurance report'")).firstMatch
        // Right after the scan closes, the first tap can be dropped (D63); try twice.
        for _ in 0..<2 where !report.waitForExistence(timeout: 3) {
            if app.tab("Reports").exists { app.tab("Reports").tap() } else { app.typeKey("3", modifierFlags: .command) }
        }
        XCTAssertTrue(report.waitForExistence(timeout: 10))
        report.tap()
        XCTAssertTrue(app.buttons["Preview Report"].waitForExistence(timeout: 10))
        app.buttons["Preview Report"].tap()
        XCTAssertTrue(app.buttons["Create Report"].waitForExistence(timeout: 10))
        snap("6 Insurance report")
    }

    @MainActor
    private func snap(_ name: String) {
        sleep(1)   // let transitions settle
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
