import XCTest

/// P6 Classic capture (C-01 to C-08). The fixture camera and scanners return fixed photos:
/// a shelf, a receipt (TOTAL $766.41 on 09/14/2026), a sticker and a valid EAN (D49).
final class CaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ store: String = "small", _ extra: [String] = ["-uiTestingCameraFixture"]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: store)
        app.launchArguments += extra
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ row: String) {
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 10))
        app.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons[row].waitForExistence(timeout: 5))
        app.buttons[row].tap()
    }

    @MainActor
    private func card(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    /// Scan room → shutter → Done → C-04, then tag each name with a tap at its spot on a
    /// 4 × 2 grid, so no box lands on another.
    @MainActor
    private func scanAndTag(_ app: XCUIApplication, _ names: [String]) {
        capture(app, "Scan room")
        let shutter = app.buttons["Take Photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"),
                                                                        object: done)], timeout: 10) == .completed)
        done.tap()
        let photo = app.otherElements["Photo 1"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        for (index, name) in names.enumerated() {
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.125 + 0.25 * Double(index % 4),
                                                            dy: index < 4 ? 0.25 : 0.75)).tap()
            let field = app.textFields["What is it?"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            if index == 0 { XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10)) }
            field.typeText(name + "\n")
            XCTAssertTrue(app.buttons["Box \(index + 1), \(name)"].waitForExistence(timeout: 5))
        }
    }

    /// Smoke S6a: a Classic room scan tags 3 items on a photo and saves them.
    @MainActor
    func testClassicScanTagsThreeItemsAndSaves() {
        let app = launch()
        scanAndTag(app, ["Toaster", "Blender", "Kettle"])
        XCTAssertTrue(app.staticTexts["3 items tagged"].exists)
        app.buttons["Save 3 Items"].tap()
        XCTAssertTrue(app.staticTexts["3 items saved."].waitForExistence(timeout: 10))
        for name in ["Toaster", "Blender", "Kettle"] {
            XCTAssertTrue(card(app, name).waitForExistence(timeout: 5), name)
        }
    }

    /// F3: the manual path saves 8 items in under 2 minutes, start to toast.
    @MainActor
    func testEightItemsTaggedUnderTwoMinutes() {
        let app = launch()
        let start = Date.now
        scanAndTag(app, ["Lamp", "Mug", "Vase", "Clock", "Radio", "Plant", "Books", "Candle"])
        app.buttons["Save 8 Items"].tap()
        XCTAssertTrue(app.staticTexts["8 items saved."].waitForExistence(timeout: 10))
        let elapsed = Date.now.timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 120, "8 items took \(Int(elapsed)) s")
    }

    /// Reviews the fixture receipt: tap the date, then the total.
    @MainActor
    private func tapDateAndTotal(_ app: XCUIApplication) {
        let date = app.buttons["Date 09/14/2026"]
        XCTAssertTrue(date.waitForExistence(timeout: 20))           // reading takes a moment
        date.tap()
        app.buttons["Amount $766.41"].tap()
        XCTAssertEqual(app.textFields["Price"].value as? String, "766.41")
        XCTAssertFalse(app.buttons["Tap a date"].exists)
        XCTAssertEqual(app.textFields["Store"].value as? String, "Tap the name, or type it")   // nothing filled by itself
        app.buttons["Save Receipt"].tap()
    }

    /// Smoke S6b: receipt tap-to-drop fills the price and date, then a new item has them.
    @MainActor
    func testReceiptTapToDropFillsPriceAndDate() {
        let app = launch()
        capture(app, "Scan receipt")
        tapDateAndTotal(app)
        let price = app.textFields["Price"]
        XCTAssertTrue(app.navigationBars["New Item"].waitForExistence(timeout: 5))
        XCTAssertEqual(price.value as? String, "766.41")
        XCTAssertTrue(app.staticTexts["Receipt photo"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        app.textFields["Name"].typeText("Espresso machine")
        app.buttons["Save"].tap()
        XCTAssertTrue(card(app, "Espresso machine").waitForExistence(timeout: 5))
    }

    /// C-06 import: a receipt opened in Nook from another app goes to the review.
    @MainActor
    func testOpenInNookShowsReceiptReview() {
        let app = launch("small", ["-uiTestingCameraFixture", "-uiTestingOpenReceipt"])
        tapDateAndTotal(app)
        XCTAssertTrue(app.navigationBars["New Item"].waitForExistence(timeout: 5))
    }

    /// Capture → Add item → shutter: the editor for a new item.
    @MainActor
    private func newItemEditor(_ app: XCUIApplication) {
        capture(app, "Add item")
        let shutter = app.buttons["Take Photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
    }

    /// C-07: the editor's Scan button fills the barcode; from C-01 a new item gets it.
    @MainActor
    func testBarcodeFillsEditor() {
        let app = launch()
        newItemEditor(app)
        app.buttons["Scan Barcode"].tap()
        let field = app.textFields["Barcode"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(NSPredicate(format: "value == '4006381333931'").evaluate(with: field)
                      || field.waitForValue("4006381333931"))
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["Discard Changes"].tap()

        capture(app, "Scan barcode")
        XCTAssertTrue(app.navigationBars["New Item"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Barcode"].waitForValue("4006381333931"))
    }

    /// C-07 with no scanner or camera: typing it is the whole screen.
    @MainActor
    func testBarcodeManualEntryWhenScannerIsOff() {
        let app = launch("small", ["-uiTestingCameraDenied"])
        capture(app, "Scan barcode")
        let field = app.textFields["Barcode"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()   // the iPad simulator shows no keyboard to wait for
        field.typeText("96385074")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["New Item"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Barcode"].waitForValue("96385074"))
    }

    /// C-08: photograph the sticker, tap the serial line, and Serial is filled.
    @MainActor
    func testSerialPickLineFillsField() {
        let app = launch()
        newItemEditor(app)
        app.buttons["Read from Sticker"].tap()
        let shutter = app.buttons["Take Photo"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        let line = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "S/N: 7XK2-48812-QA")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 20))
        line.tap()
        XCTAssertTrue(app.textFields["Serial number"].waitForValue("7XK2-48812-QA"))
    }

    /// C-02 with the camera turned off: Photos and Settings, never a dead end (D15).
    @MainActor
    func testCameraDeniedOffersPhotos() {
        let app = launch("small", ["-uiTestingCameraDenied"])
        capture(app, "Scan room")
        XCTAssertTrue(app.staticTexts["Camera is off for Nook"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pick from Photos"].exists)
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 5))
    }
}

private extension XCUIElement {
    /// Waits for a text field to show `value`.
    func waitForValue(_ value: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
