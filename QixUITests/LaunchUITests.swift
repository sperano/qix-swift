import XCTest

/// The app as a player first sees it: in landscape, the playfield on screen at the board's shape.
@MainActor
final class LaunchUITests: XCTestCase {
    private static let timeout: TimeInterval = 10
    /// The board's width over its height, 160 by 120 cells.
    private static let boardAspectRatio: CGFloat = 4.0 / 3.0
    /// How far the playfield's ratio may stray from the board's: its frame is rounded to pixels.
    private static let ratioTolerance: CGFloat = 0.01

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTheAppOpensInLandscape() {
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height)
    }

    func testThePlayfieldIsOnScreenAtTheBoardsShape() {
        let playfield = app.descendants(matching: .any)["playfield"]
        XCTAssertTrue(playfield.waitForExistence(timeout: Self.timeout))
        let frame = playfield.frame
        XCTAssertTrue(app.windows.firstMatch.frame.contains(frame), "\(frame) is not inside the window")
        XCTAssertEqual(frame.width / frame.height, Self.boardAspectRatio, accuracy: Self.ratioTolerance)
    }
}
