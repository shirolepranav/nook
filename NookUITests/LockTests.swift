import XCTest
import AppIntentsTesting

/// P12: the app lock (L-02, S-05), Private items behind Face ID (PRD §9, D61), and Siri and
/// Shortcuts through the App Intents (04 §8). Face ID is faked with `-uiTestingBiometrics`.
final class LockTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(biometrics: String, _ arguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.nook(store: "lived")
        app.launchArguments += ["-uiTestingBiometrics", biometrics] + arguments
        app.launch()
        return app
    }

    @MainActor
    private func findPassport(_ app: XCUIApplication) -> XCUIElement {
        app.tab("Find").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("passport")
        let row = app.buttons["Private item. Unlock to see it"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        return row
    }

    /// Smoke S12, first part: with the lock on, Nook opens on L-02, and a failed Face ID
    /// says so and keeps it locked.
    @MainActor
    func testLockedLaunchStaysLockedWhenFaceIDFails() {
        let app = launch(biometrics: "failure", ["-uiTestingLockOn"])
        XCTAssertTrue(app.staticTexts["Nook is locked"].waitForExistence(timeout: 10))
        let unlock = app.buttons["Unlock with Face ID"]
        XCTAssertTrue(unlock.exists)
        unlock.tap()
        let failed = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Face ID didn’t recognize you")).firstMatch
        XCTAssertTrue(failed.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tab("Home").isHittable)
    }

    /// With Face ID passing, L-02 unlocks on its own and Home is there.
    @MainActor
    func testLockedLaunchUnlocksWithFaceID() {
        let app = launch(biometrics: "success", ["-uiTestingLockOn"])
        XCTAssertTrue(app.tab("Home").waitForExistence(timeout: 10))
        let locked = app.staticTexts["Nook is locked"]
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: locked)
        wait(for: [gone], timeout: 5)
        XCTAssertTrue(app.tab("Home").isHittable)
    }

    /// S-05: the switch asks first, then Lock after appears.
    @MainActor
    func testTurningTheLockOnShowsLockAfter() {
        let app = launch(biometrics: "success")
        app.tab("Settings").tap()
        app.settingsRow("Face ID Lock").tap()
        let toggle = app.switches["Lock Nook with Face ID"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Lock after"].waitForExistence(timeout: 5))
    }

    /// A Private item stays masked in Find when Face ID fails.
    @MainActor
    func testPrivateItemStaysHiddenWhenFaceIDFails() {
        let app = launch(biometrics: "failure")
        findPassport(app).tap()
        sleep(1)
        XCTAssertFalse(app.staticTexts["Passport"].exists)
        XCTAssertTrue(app.buttons["Private item. Unlock to see it"].exists)
    }

    /// A Private item opens after Face ID.
    @MainActor
    func testPrivateItemOpensAfterFaceID() {
        let app = launch(biometrics: "success")
        findPassport(app).tap()
        XCTAssertTrue(app.staticTexts["Passport"].waitForExistence(timeout: 5))
    }

    /// Smoke S12, last part: FindItemIntent answers from Shortcuts, and a Private item is
    /// neither an entity nor in Spotlight.
    @MainActor
    func testFindItemIntentAnswersAndKeepsPrivateItemsOut() async throws {
        let app = launch(biometrics: "success")
        XCTAssertTrue(app.tab("Home").waitForExistence(timeout: 10))
        let definitions = IntentDefinitions(bundleIdentifier: "pranav.nook")
        let items = definitions.entities["ItemEntity"]
        let drills = try await items.entities(matching: "drill")
        let drill = try XCTUnwrap(drills.first)
        let intent = definitions.intents["FindItemIntent"].makeIntent(item: drill)
        let result = try await intent.run()
        let answer: String = try result.value
        XCTAssertTrue(answer.hasPrefix("Jordan has your Cordless drill") || answer.contains("Garage"), answer)
        let passports = try await items.entities(matching: "passport")
        XCTAssertTrue(passports.isEmpty)
    }
}
