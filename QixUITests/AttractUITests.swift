import XCTest

/// The attract demo: the title left idle plays it under its banner, a touch on a control stops it
/// and a tap on the board starts a game.
@MainActor
final class AttractUITests: XCTestCase {
    /// Longer than the title's 10 seconds of idle before the demo, with room for a slow launch.
    private static let demoTimeout: TimeInterval = 30
    private static let timeout: TimeInterval = 10

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

    /// Waits for the demo's banner, which replaces the title screen.
    private func waitForTheDemo(file: StaticString = #filePath, line: UInt = #line) {
        let banner = element("banner")
        XCTAssertTrue(banner.waitForExistence(timeout: Self.demoTimeout), "no demo", file: file, line: line)
        XCTAssertTrue(banner.label.contains("DEMO"), "\(banner.label)", file: file, line: line)
        XCTAssertFalse(element("screen").exists, "the title screen is still up", file: file, line: line)
    }

    func testATapOnTheDemoStartsAGame() {
        waitForTheDemo()

        element("playfield").tap()

        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: Self.timeout))
        XCTAssertFalse(element("banner").exists)
    }

    func testATouchOnTheStickStopsTheDemoAndShowsTheTitle() {
        waitForTheDemo()

        element("stick").tap()

        XCTAssertTrue(element("banner").waitForNonExistence(timeout: Self.timeout))
        XCTAssertTrue(element("screen").waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element("screen").label.contains("QIX"), "\(element("screen").label)")
        XCTAssertFalse(app.buttons["pause"].exists)
    }
}
