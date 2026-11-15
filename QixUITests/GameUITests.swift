import XCTest

/// The game as a player starts it with taps alone: the title screen, a tap to start, the HUD's
/// pause button to pause and resume.
@MainActor
final class GameUITests: XCTestCase {
    private static let timeout: TimeInterval = 10

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private var screen: XCUIElement {
        app.descendants(matching: .any)["screen"]
    }

    private var pauseButton: XCUIElement {
        app.buttons["pause"]
    }

    /// Waits for the screen over the board to appear, then checks that it shows `heading`.
    private func assertScreen(_ heading: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(screen.waitForExistence(timeout: Self.timeout), "no screen", file: file, line: line)
        XCTAssertTrue(screen.label.contains(heading), "\(screen.label)", file: file, line: line)
    }

    func testTheAppOpensOnTheTitleScreenWithoutPauseButton() {
        assertScreen("QIX")
        XCTAssertFalse(pauseButton.exists)
    }

    func testATapStartsTheGameAndThePauseButtonPausesAndResumesIt() {
        assertScreen("QIX")

        app.descendants(matching: .any)["playfield"].tap()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(screen.exists)
        XCTAssertEqual(pauseButton.label, "Pause")

        pauseButton.tap()
        assertScreen("PAUSED")
        XCTAssertEqual(pauseButton.label, "Resume")

        pauseButton.tap()
        XCTAssertTrue(screen.waitForNonExistence(timeout: Self.timeout))
    }
}
