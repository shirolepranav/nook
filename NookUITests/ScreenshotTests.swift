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
        app.buttons["Recently Deleted"].tap()
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
        XCTAssertTrue(off.staticTexts["Camera is off for Nook"].waitForExistence(timeout: 5))
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
        app.buttons["Notifications"].tap()
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
        empty.buttons["Notifications"].tap()
        XCTAssertTrue(empty.staticTexts["Reminders are off for Nook"].waitForExistence(timeout: 5))
        snap("S-07 Denied")
    }

    /// Half a screen, slower than a swipe, so it doesn't fling past what it's looking for.
    @MainActor
    private func shortDrag(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
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
