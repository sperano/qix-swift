import XCTest

/// The App Store screenshots, attached to the test result for `Scripts/screenshots.sh` to export.
/// Skipped unless the script runs it: it sets `SCREENSHOT_LOCALE` (as `TEST_RUNNER_SCREENSHOT_LOCALE`).
@MainActor
final class ScreenshotUITests: XCTestCase {
    private static let localeVariable = "SCREENSHOT_LOCALE"
    private static let timeout: TimeInterval = 10
    /// Longer than the title's 10 seconds of idle before the demo, with room for a slow launch.
    private static let demoTimeout: TimeInterval = 30
    /// How far into the demo the first picture is: its second claim is done and the third line is
    /// rising (the script's timings, in `Demo.demoScript`, at 60 ticks a second).
    private static let demoProgress: TimeInterval = 15
    /// Lets a sheet or a page slide in before the picture; a simulator just booted is slow.
    private static let animationSettle: TimeInterval = 2
    /// The drag on the stick that draws the game's line, in points: well past its dead zone.
    private static let dragDistance: CGFloat = 40
    /// How long the thumb rests before dragging, and holds the drag while the line grows.
    private static let pressDuration: TimeInterval = 0.1
    private static let drawDuration: TimeInterval = 1
    /// The game's picture is taken as the thumb lifts, before the fuse lights.
    private static let immediately: TimeInterval = 0

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        guard let locale = ProcessInfo.processInfo.environment[Self.localeVariable] else {
            throw XCTSkip("screenshots are taken by Scripts/screenshots.sh")
        }
        // "en-US" is the language; the region format wants "en_US".
        let region = locale.replacingOccurrences(of: "-", with: "_")
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        // Default settings and an empty high score table, whatever an earlier run saved.
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(\(locale))", "-AppleLocale", region]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The marker's lattice point, as the playfield's accessibility value reads it.
    private func markerPosition() -> [Int] {
        let value = element("playfield").value as? String ?? ""
        let numbers = value.split { !$0.isNumber }.compactMap { Int($0) }
        XCTAssertEqual(numbers.count, 2, "no marker in \(value)")
        return numbers
    }

    /// Waits `settle` seconds, then attaches the screen as `name`. The wait is the picture's own
    /// timing (how far a demo or an animation got), not a stand-in for an element to appear.
    private func snap(_ name: String, after settle: TimeInterval = animationSettle) {
        Thread.sleep(forTimeInterval: settle)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDemoAndGame() {
        XCTAssertTrue(element("banner").waitForExistence(timeout: Self.demoTimeout), "no demo")
        snap("01-demo", after: Self.demoProgress)

        // A tap on the demo starts a game; the marker starts on the bottom border, so a drag up
        // on the stick draws a fast line into the open.
        element("playfield").tap()
        XCTAssertTrue(app.buttons["pause"].waitForExistence(timeout: Self.timeout))
        let start = markerPosition()
        let centre = element("stick").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let up = centre.withOffset(CGVector(dx: 0, dy: -Self.dragDistance))
        centre.press(
            forDuration: Self.pressDuration, thenDragTo: up, withVelocity: .default,
            thenHoldForDuration: Self.drawDuration
        )
        snap("02-game", after: Self.immediately)
        // Read after the picture, which the read would delay: a board with no line fails the run.
        XCTAssertNotEqual(markerPosition()[1], start[1], "the drag drew no line")
    }

    func testSettingsAndHowToPlay() {
        let settings = app.buttons["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: Self.timeout))
        settings.tap()
        XCTAssertTrue(app.buttons["settingsDone"].waitForExistence(timeout: Self.timeout))
        snap("03-settings")

        app.buttons["howToPlayLink"].tap()
        XCTAssertTrue(element("howToPlay").waitForExistence(timeout: Self.timeout))
        snap("04-how-to-play")
    }
}
