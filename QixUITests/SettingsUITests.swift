import XCTest

/// The settings sheet as a player opens it from the title screen's gear, its How to play page,
/// and the left-handed swap of the touch controls it makes.
@MainActor
final class SettingsUITests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// Swipes the sheet is given to bring a control into view.
    private static let maxSwipes = 4

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    private var settingsButton: XCUIElement {
        app.buttons["settings"]
    }

    private var doneButton: XCUIElement {
        app.buttons["settingsDone"]
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Taps the title screen's gear and waits for the sheet.
    private func openSettings(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(settingsButton.waitForExistence(timeout: Self.timeout), file: file, line: line)
        settingsButton.tap()
        XCTAssertTrue(doneButton.waitForExistence(timeout: Self.timeout), "no sheet", file: file, line: line)
    }

    /// Taps Done and waits for the sheet to go.
    private func closeSettings(file: StaticString = #filePath, line: UInt = #line) {
        doneButton.tap()
        XCTAssertTrue(doneButton.waitForNonExistence(timeout: Self.timeout), "the sheet stayed", file: file, line: line)
    }

    func testTheGearOpensTheSettingsAndDoneClosesThemBackToTheTitle() {
        openSettings()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        closeSettings()

        XCTAssertTrue(settingsButton.exists)
        XCTAssertTrue(element("screen").label.contains("QIX"), element("screen").label)
    }

    func testHowToPlayOpensFromTheSettingsAndGoesBackToThem() {
        openSettings()
        let link = app.buttons["howToPlayLink"]
        XCTAssertTrue(link.waitForExistence(timeout: Self.timeout))
        link.tap()

        XCTAssertTrue(app.navigationBars["How to play"].waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(app.staticTexts["Claim 75% of the board to clear the level."].exists)

        app.navigationBars["How to play"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.timeout))
        closeSettings()
    }

    func testLeftHandedPutsTheStickRightOfTheSlowButton() {
        let stick = element("stick")
        let slow = element("slow")
        XCTAssertTrue(stick.waitForExistence(timeout: Self.timeout))
        XCTAssertLessThan(stick.frame.midX, slow.frame.midX)

        openSettings()
        let toggle = app.switches["leftHanded"]
        XCTAssertTrue(toggle.waitForExistence(timeout: Self.timeout))
        for _ in 0 ..< Self.maxSwipes where !toggle.isHittable {
            app.swipeUp()
        }
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        closeSettings()

        XCTAssertGreaterThan(stick.frame.midX, slow.frame.midX)
    }
}
