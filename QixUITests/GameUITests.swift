import XCTest

/// The game as a player starts it with taps alone: the title screen, a tap to start, the HUD's
/// pause button to pause and resume, and a drag on the stick to steer.
@MainActor
final class GameUITests: XCTestCase {
    private static let timeout: TimeInterval = 10

    /// The drag on the stick, in points: well past its 12-point dead zone.
    private static let dragDistance: CGFloat = 40
    /// How long the thumb rests before dragging, and holds the drag before lifting, in seconds.
    private static let pressDuration: TimeInterval = 0.1
    private static let holdDuration: TimeInterval = 1

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

    /// The marker's lattice point, as the playfield's accessibility value reads it.
    private func markerPosition(file: StaticString = #filePath, line: UInt = #line) -> [Int] {
        let value = app.descendants(matching: .any)["playfield"].value as? String ?? ""
        let numbers = value.split { !$0.isNumber }.compactMap { Int($0) }
        XCTAssertEqual(numbers.count, 2, "no marker in \(value)", file: file, line: line)
        return numbers
    }

    /// The marker starts on the bottom border: a drag to the left holds left, and the marker
    /// moves along the border while the drag is held.
    func testADragOnTheStickMovesTheMarker() {
        assertScreen("QIX")
        app.descendants(matching: .any)["playfield"].tap()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: Self.timeout))
        let start = markerPosition()

        let stick = app.descendants(matching: .any)["stick"]
        XCTAssertTrue(stick.exists)
        let centre = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let left = centre.withOffset(CGVector(dx: -Self.dragDistance, dy: 0))
        centre.press(
            forDuration: Self.pressDuration, thenDragTo: left, withVelocity: .default,
            thenHoldForDuration: Self.holdDuration
        )

        let moved = markerPosition()
        XCTAssertLessThan(moved[0], start[0], "the marker did not move left")
        XCTAssertEqual(moved[1], start[1], "the marker left the bottom border")
    }
}
