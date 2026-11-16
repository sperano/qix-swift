import QixKit
import XCTest
@testable import Qix

/// One frame at the tick rate: one tick.
private let attractFrame: TimeInterval = 1.0 / Double(Tuning.tickHz)

/// Frames a test may run before the demo must have claimed: well past its first rectangle.
private let claimBudget = 2 * Int(Tuning.attractDelayTicks)

/// A stand-in for a `UITouch`: only its identity counts.
private final class AttractFinger: Sendable {}

private let attractFinger = AttractFinger()
private let attractTouch = ObjectIdentifier(attractFinger)

/// Where the touch lands on the stick's zone, in the playfield's coordinates.
private let stickPoint = CGPoint(x: 60, y: 200)

/// The attract demo as the model shows it: the demo's game under its banner, its board drawn, its
/// claims flashing, and stopped by any touch.
@MainActor
final class GameModelAttractTests: XCTestCase {
    private var model: GameModel!

    override func setUp() async throws {
        try await super.setUp()
        model = GameModel(session: Session(game: Game(rng: Rng(seed: 0))))
    }

    private func frames(_ count: UInt32) {
        for _ in 0 ..< count {
            model.advance(by: attractFrame, pad: nil)
        }
    }

    /// Sits on the title until the demo starts.
    private func startDemo(file: StaticString = #filePath, line: UInt = #line) {
        frames(Tuning.attractDelayTicks)
        XCTAssertNotNil(model.loop.attract.demo, "the demo plays", file: file, line: line)
    }

    /// Runs frames until the demo has claimed cells; returns whether it did within the budget.
    private func playDemoUntilItClaims() -> Bool {
        for _ in 0 ..< claimBudget {
            if model.loop.shownGame.board.claimedFraction() > 0 {
                return true
            }
            frames(1)
        }
        return false
    }

    func testTheTitleShowsItsScreenUntilTheDemoStarts() {
        frames(Tuning.attractDelayTicks - 1)

        XCTAssertEqual(model.scene.screen, .title(HighScores()))
        XCTAssertNil(model.scene.banner)
    }

    func testTheDemoPlaysUnderItsBannerWithoutTheTitleScreen() throws {
        startDemo()
        frames(1)

        let scene = model.scene
        let demo = try XCTUnwrap(model.loop.attract.demo)
        XCTAssertEqual(scene.banner, .demo)
        XCTAssertNil(scene.screen)
        XCTAssertEqual(scene.game, demo.game)
        XCTAssertEqual(scene.hud, Hud(game: demo.game, highScore: model.session.highScore))
        XCTAssertEqual(scene.hudButton, .settings)
    }

    func testTheDemosClaimsAreDrawnAndFlash() throws {
        startDemo()

        XCTAssertTrue(playDemoUntilItClaims(), "the demo claimed nothing")

        XCTAssertEqual(model.board.board, model.loop.shownGame.board)
        let claim = try XCTUnwrap(model.scene.claim, "no claim flashes")
        XCTAssertEqual(claim.runs, BoardShapes.claimedRuns(model.loop.shownGame.board))
        XCTAssertEqual(claim.progress, 0)
    }

    func testATouchOnAControlStopsTheDemoWithoutStartingAGame() {
        startDemo()

        model.touch(.began(touch: attractTouch, on: .stick, at: stickPoint))
        model.touch(.ended(touch: attractTouch))
        frames(1)

        XCTAssertNil(model.loop.attract.demo)
        XCTAssertEqual(model.session.state, .title)
        XCTAssertEqual(model.scene.screen, .title(HighScores()))
        XCTAssertNil(model.scene.banner)
    }

    func testATapStopsTheDemoAndStartsAGame() {
        startDemo()

        model.tap()
        frames(1)

        XCTAssertNil(model.loop.attract.demo)
        XCTAssertEqual(model.session.state, .playing)
        XCTAssertEqual(model.scene.game, model.session.game)
    }

    func testOpeningTheSettingsStopsTheDemo() {
        startDemo()

        model.openSettings()

        XCTAssertNil(model.loop.attract.demo)
        XCTAssertNil(model.scene.banner)
    }
}
