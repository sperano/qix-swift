import XCTest

/// Follow the finger as a player picks it in the settings: the stick goes, the board takes the
/// touches, a tap on it still starts the game and a finger on it steers.
@MainActor
final class FollowTheFingerUITests: XCTestCase {
    private static let timeout: TimeInterval = 10

    /// Where the finger lands on the board, as a fraction of its size: low on the left, so the
    /// target, 40 points above it, lies further left of the marker than above it.
    private static let landing = CGVector(dx: 0.05, dy: 0.95)
    /// How far left the finger then drags, in points: off the board, so the target is clamped onto
    /// its left edge, on the border.
    private static let dragDistance: CGFloat = 40
    /// How long the finger rests before dragging, and holds the drag before lifting, in seconds.
    private static let pressDuration: TimeInterval = 0.1
    private static let holdDuration: TimeInterval = 1

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Picks Follow the finger in the settings sheet and closes it.
    private func followTheFinger() {
        let settings = app.buttons["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: Self.timeout))
        settings.tap()
        let scheme = element("controlScheme")
        XCTAssertTrue(scheme.waitForExistence(timeout: Self.timeout), "no sheet")
        scheme.tap()
        let option = app.buttons["Follow the finger"]
        XCTAssertTrue(option.waitForExistence(timeout: Self.timeout), "no Follow the finger option")
        option.tap()
        let done = app.buttons["settingsDone"]
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: Self.timeout), "the sheet stayed")
    }

    /// The marker's lattice point, as the playfield's accessibility value reads it.
    private func markerPosition() -> [Int] {
        let value = element("playfield").value as? String ?? ""
        let numbers = value.split { !$0.isNumber }.compactMap { Int($0) }
        XCTAssertEqual(numbers.count, 2, "no marker in \(value)")
        return numbers
    }

    /// The marker starts on the bottom border: it heads left along it for the finger's target.
    func testAFingerOnTheBoardSteersTheMarker() {
        followTheFinger()
        XCTAssertFalse(element("stick").exists)
        XCTAssertTrue(element("slow").exists)
        let board = element("board")
        XCTAssertTrue(board.exists)

        board.tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: Self.timeout), "the tap did not start")
        let start = markerPosition()
        let landing = board.coordinate(withNormalizedOffset: Self.landing)
        landing.press(
            forDuration: Self.pressDuration, thenDragTo: landing.withOffset(CGVector(dx: -Self.dragDistance, dy: 0)),
            withVelocity: .default, thenHoldForDuration: Self.holdDuration
        )

        let moved = markerPosition()
        XCTAssertLessThan(moved[0], start[0], "the marker did not move left")
        XCTAssertEqual(moved[1], start[1], "the marker left the bottom border")
    }
}
