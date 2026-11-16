import XCTest
@testable import QixKit

/// The time of a frame that runs one tick, in seconds.
private let oneTick = 1 / Float(Tuning.tickHz)

/// Frames a test may run before what it waits for must have happened: well past a whole demo.
private let frameBudget = 4 * Int(Tuning.attractDelayTicks)

/// Runs `ticks` frames of one tick each, nothing held.
private func idle(_ loop: inout GameLoop, _ ticks: UInt32, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0 ..< ticks {
        XCTAssertEqual(loop.advance(oneTick), 1, file: file, line: line)
    }
}

/// Runs frames of one tick until `done` holds, at most `frameBudget` of them; returns whether it
/// came to hold.
@discardableResult
private func idle(_ loop: inout GameLoop, until done: (GameLoop) -> Bool) -> Bool {
    for _ in 0 ..< frameBudget {
        if done(loop) {
            return true
        }
        loop.advance(oneTick)
    }
    return done(loop)
}

/// A loop on the title screen of a new full-size game.
private func attractLoop() -> GameLoop {
    GameLoop(session: Session(game: Game(rng: Rng(seed: 0))))
}

/// `attractLoop` after the idle ticks that start its demo.
private func demoLoop(file: StaticString = #filePath, line: UInt = #line) -> GameLoop {
    var loop = attractLoop()
    idle(&loop, Tuning.attractDelayTicks, file: file, line: line)
    XCTAssertNotNil(loop.attract.demo, "the demo plays", file: file, line: line)
    return loop
}

/// The demo has claimed cells.
private func demoClaimed(_ loop: GameLoop) -> Bool {
    (loop.attract.demo?.game.board.claimedFraction() ?? 0) > 0
}

final class GameLoopAttractTests: XCTestCase {
    func testTheTitleStartsTheDemoAfterSittingIdle() {
        var loop = attractLoop()

        idle(&loop, Tuning.attractDelayTicks - 1)
        XCTAssertNil(loop.attract.demo)
        idle(&loop, 1)

        XCTAssertNotNil(loop.attract.demo)
        XCTAssertEqual(loop.session.state, .title)
    }

    func testTheGameShownIsTheDemosWhileItPlaysAndTheSessionsOtherwise() throws {
        var loop = attractLoop()
        XCTAssertEqual(loop.shownGame, loop.session.game)
        idle(&loop, Tuning.attractDelayTicks + 1)

        let demo = try XCTUnwrap(loop.attract.demo)
        XCTAssertEqual(loop.shownGame, demo.game)
        XCTAssertNotEqual(loop.shownGame, loop.session.game)
    }

    func testATapStopsTheDemoAndStartsAGame() {
        var loop = demoLoop()
        loop.controls.press(.confirm)

        loop.advance(oneTick)

        XCTAssertNil(loop.attract.demo)
        XCTAssertEqual(loop.session.state, .playing)
    }

    func testAHeldKeyStopsTheDemoWithoutStartingAGame() {
        var loop = demoLoop()
        loop.controls.keyDown(.left)

        loop.advance(oneTick)

        XCTAssertNil(loop.attract.demo)
        XCTAssertEqual(loop.session.state, .title)
    }

    func testATouchStopsTheDemoAndRestartsTheIdleCount() {
        var loop = demoLoop()

        loop.touchDown()

        XCTAssertNil(loop.attract.demo)
        XCTAssertEqual(loop.session.state, .title)
        idle(&loop, Tuning.attractDelayTicks - 1)
        XCTAssertNil(loop.attract.demo)
        idle(&loop, 1)
        XCTAssertNotNil(loop.attract.demo)
    }

    func testATouchBeforeTheDemoRestartsTheIdleCount() {
        var loop = attractLoop()
        idle(&loop, Tuning.attractDelayTicks - 1)

        loop.touchDown()
        idle(&loop, 1)

        XCTAssertNil(loop.attract.demo)
    }

    func testNoDemoPlaysOffTheTitle() {
        var loop = attractLoop()
        loop.controls.press(.confirm)
        loop.advance(oneTick)
        loop.controls.press(.pause)
        loop.advance(oneTick)
        XCTAssertEqual(loop.session.state, .paused)

        idle(&loop, Tuning.attractDelayTicks)

        XCTAssertNil(loop.attract.demo)
    }

    func testSuspendingStopsTheDemo() {
        var loop = demoLoop()

        loop.suspend()

        XCTAssertNil(loop.attract.demo)
        XCTAssertEqual(loop.session.state, .title)
    }

    /// The demo claims three rectangles, then ends and the title sits idle again; none of it is
    /// heard or felt.
    func testAWholeDemoPlaysSilentlyAndEndsOnTheTitle() {
        var loop = demoLoop()
        var claimed = false

        let ended = idle(&loop) { loop in
            claimed = claimed || demoClaimed(loop)
            return loop.attract.demo == nil
        }

        XCTAssertTrue(claimed, "the demo claimed nothing")
        XCTAssertTrue(ended, "the demo did not end")
        XCTAssertEqual(loop.session.state, .title)
        XCTAssertEqual(loop.takeSounds(), [])
        XCTAssertEqual(loop.takeHaptics(), [])
    }
}

/// The claim animation of the game shown.
final class GameLoopClaimFillTests: XCTestCase {
    func testANewLoopAnimatesNoClaim() {
        XCTAssertNil(GameLoop(session: Session(game: levelGame())).claimFill.fresh)
    }

    func testAClaimOfTheDemoFlashesTheCellsItTook() throws {
        var loop = demoLoop()

        XCTAssertTrue(idle(&loop, until: demoClaimed), "the demo claimed nothing")

        let fresh = try XCTUnwrap(loop.claimFill.fresh, "no claim animated")
        XCTAssertEqual(fresh.progress, 0)
        XCTAssertEqual(fresh.runs, BoardShapes.claimedRuns(loop.shownGame.board))
        XCTAssertFalse(fresh.runs.isEmpty)
    }

    func testTheFlashMovesOnWithEachTick() throws {
        var loop = demoLoop()
        idle(&loop, until: demoClaimed)

        idle(&loop, 1)

        let progress = try XCTUnwrap(loop.claimFill.fresh).progress
        XCTAssertEqual(progress, 1 / Float(ClaimFill.claimFillTicks))
    }

    /// The board shown goes back to the title's, which has lost the demo's claims: not a claim.
    func testStoppingTheDemoStopsItsFlash() {
        var loop = demoLoop()
        idle(&loop, until: demoClaimed)
        XCTAssertNotNil(loop.claimFill.fresh)

        loop.touchDown()
        idle(&loop, 1)

        XCTAssertNil(loop.claimFill.fresh)
    }

    /// In play, the session's own claims flash: a 2-cell square drawn up from the marker's start.
    func testAClaimInPlayFlashes() throws {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        var loop = GameLoop(session: Session(game: Game(
            board: board,
            qix: [qixAt((0, 0))],
            sparx: [],
            rng: Rng(seed: 0)
        )))
        loop.controls.press(.confirm)
        loop.advance(oneTick)
        let start = loop.session.game.marker.pos
        loop.controls.keyDown(.fast)

        for (dir, to) in [
            (Control.up, Point(x: start.x, y: start.y - 2)),
            (.right, Point(x: start.x + 2, y: start.y - 2)),
        ] {
            loop.controls.keyDown(dir)
            XCTAssertTrue(idle(&loop) { $0.session.game.marker.pos == to }, "the marker did not reach \(to)")
            loop.controls.keyUp(dir)
        }
        loop.controls.keyDown(.down)
        XCTAssertTrue(idle(&loop) { $0.claimFill.fresh != nil }, "no claim animated")

        let fresh = try XCTUnwrap(loop.claimFill.fresh)
        XCTAssertEqual(
            fresh.runs,
            [start.y - 2, start.y - 1].map { CellRun(row: $0, cols: start.x ..< start.x + 2, kind: .fast) }
        )
        XCTAssertEqual(fresh.progress, 0)
    }
}
