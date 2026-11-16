import XCTest
@testable import QixKit

/// Frame times of the refresh rates the app runs at, in seconds.
private let frame60: Float = 1 / 60
private let frame120: Float = 1 / 120
private let frame30: Float = 1 / 30

/// Frames the tests that hold a key run.
private let heldFrames = 20

/// A loop over a new `levelGame` session, on its title screen.
private func titleLoop() -> GameLoop {
    GameLoop(session: Session(game: levelGame()))
}

/// A loop whose game is in play, after the frame that started it.
private func playingLoop(file: StaticString = #filePath, line: UInt = #line) -> GameLoop {
    var loop = titleLoop()
    loop.controls.press(.confirm)
    loop.advance(frame60)
    XCTAssertEqual(loop.session.state, .playing, file: file, line: line)
    return loop
}

/// A loop over a free full board in play, its Qix in the top-left cell, its marker at `(80, 120)`.
private func steeringLoop(file: StaticString = #filePath, line: UInt = #line) -> GameLoop {
    let board = Board(width: Tuning.boardW, height: Tuning.boardH)
    var loop = GameLoop(session: Session(game: Game(board: board, qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: 0))))
    loop.controls.press(.confirm)
    loop.advance(frame60)
    XCTAssertEqual(loop.session.state, .playing, file: file, line: line)
    return loop
}

/// The aim at lattice point `(80, y)`, above the marker of `steeringLoop`.
private func aimUp(_ y: UInt16) -> Vec2 {
    Vec2(Point(x: 80, y: y))
}

final class GameLoopTests: XCTestCase {
    func testAFrameRunsTheTicksItOwes() {
        var loop = playingLoop()

        XCTAssertEqual(loop.advance(frame30), 2)
        XCTAssertEqual(loop.session.game.ticks, 2)
    }

    func testATapStartsTheGameOnTheFrameThatFollows() {
        var loop = titleLoop()
        loop.controls.press(.confirm)

        loop.advance(frame60)

        XCTAssertEqual(loop.session.state, .playing)
        XCTAssertEqual(loop.session.game.ticks, 0)
    }

    func testAPressInAFrameWithoutTicksStartsTheGameOnTheNextTick() {
        var loop = titleLoop()
        loop.controls.press(.confirm)

        XCTAssertEqual(loop.advance(frame120), 0)
        XCTAssertEqual(loop.session.state, .title)
        XCTAssertEqual(loop.advance(frame120), 1)
        XCTAssertEqual(loop.session.state, .playing)
    }

    func testAPressReachesOneTickOfAFrameRunningSeveral() {
        var loop = playingLoop()
        loop.controls.press(.pause)

        XCTAssertEqual(loop.advance(frame30), 2)

        // A second pause on the second tick would have resumed the game.
        XCTAssertEqual(loop.session.state, .paused)
    }

    func testAHeldPauseKeyPausesOnceAtAnyRate() {
        for dt in [frame60, frame120] {
            var loop = playingLoop()
            loop.controls.keyDown(.pause)
            for _ in 0 ..< heldFrames {
                loop.controls.keyDown(.pause)
                loop.advance(dt)
            }

            XCTAssertEqual(loop.session.state, .paused, "dt = \(dt)")
        }
    }

    func testAHeldDirectionMovesTheMarker() {
        var loop = playingLoop()
        let start = loop.session.game.marker.pos
        loop.controls.keyDown(.left)

        loop.advance(Float(Tuning.markerStepTicks) * frame60)

        XCTAssertEqual(loop.session.game.marker.pos, Point(x: start.x - 1, y: start.y))
    }

    func testSuspendingPausesAGameInPlayWithoutATick() {
        var loop = playingLoop()
        loop.advance(frame60)
        let game = loop.session.game

        loop.suspend()

        XCTAssertEqual(loop.session.state, .paused)
        XCTAssertEqual(loop.session.game, game)
    }

    func testSuspendingLeavesAPausedGamePaused() {
        var loop = playingLoop()
        loop.controls.press(.pause)
        loop.advance(frame60)
        XCTAssertEqual(loop.session.state, .paused)

        loop.suspend()

        // A pause tick would have resumed the game.
        XCTAssertEqual(loop.session.state, .paused)
    }

    func testSuspendingLeavesAScreenOutOfPlayAlone() {
        var loop = titleLoop()

        loop.suspend()

        XCTAssertEqual(loop.session.state, .title)
    }

    func testSuspendingDropsTheHeldKeysAndThePressesNotYetDelivered() {
        var loop = playingLoop()
        loop.controls.keyDown(.left)
        loop.controls.press(.pause)
        XCTAssertEqual(loop.advance(frame120), 0)

        loop.suspend()
        loop.advance(frame60)

        // The pause pressed before suspending would have resumed the game.
        XCTAssertEqual(loop.session.state, .paused)
        XCTAssertEqual(loop.controls.held, [])
    }

    func testSuspendingDropsTheHeldTouchControls() {
        var loop = playingLoop()
        loop.controls.setTouch([.left, .slow])

        loop.suspend()

        XCTAssertEqual(loop.controls.held, [])
    }

    func testSuspendingKeepsTheGamePadHeld() {
        var loop = playingLoop()
        loop.controls.setPad([.slow])

        loop.suspend()

        XCTAssertEqual(loop.controls.held, [.slow])
    }
}

/// The initials the hold tests type.
private let typedName = "QIX"

/// Lives the rules of `testNewRulesRestartTheTitlesGameWithThem` start a game with, off the
/// default.
private let ruledLives: UInt32 = 5

/// A loop whose session waits for the initials of a game over that made the empty table.
private func enteringLoop(file: StaticString = #filePath, line: UInt = #line) -> GameLoop {
    var loop = GameLoop(session: scoredGameOver(HighScores(), file: file, line: line))
    loop.controls.press(.confirm)
    loop.advance(frame60)
    XCTAssertTrue(loop.isEnteringInitials, "\(loop.session.state)", file: file, line: line)
    return loop
}

final class GameLoopHoldTests: XCTestCase {
    func testALoopPlayingIsNotOnHold() {
        let loop = playingLoop()

        XCTAssertFalse(loop.isInterrupted)
        XCTAssertFalse(loop.isEnteringInitials)
        XCTAssertFalse(loop.isOnHold)
    }

    func testInterruptingPausesAGameInPlayAndRunsNoTick() {
        var loop = playingLoop()

        loop.interrupt()
        let game = loop.session.game
        loop.controls.keyDown(.left)
        loop.controls.press(.pause)

        XCTAssertTrue(loop.isInterrupted)
        XCTAssertTrue(loop.isOnHold)
        XCTAssertEqual(loop.advance(frame30), 0)
        XCTAssertEqual(loop.session.state, .paused)
        XCTAssertEqual(loop.session.game, game)
    }

    func testAPressDuringAnInterruptionDoesNotActAfterTheResume() {
        var loop = titleLoop()
        loop.interrupt()
        loop.controls.press(.confirm)
        XCTAssertEqual(loop.advance(frame60), 0)

        loop.resume()

        XCTAssertEqual(loop.advance(frame60), 1)
        XCTAssertEqual(loop.session.state, .title)
    }

    func testResumingDropsTheKeysAndTouchesOfTheInterruption() {
        var loop = titleLoop()
        loop.interrupt()
        loop.controls.keyDown(.left)
        loop.controls.setTouch([.up, .fast])
        loop.controls.press(.confirm)

        loop.resume()

        XCTAssertFalse(loop.isOnHold)
        XCTAssertEqual(loop.controls.held, [])
        XCTAssertEqual(loop.controls.sample(), InputState())
    }

    func testTheLoopIsOnHoldWhileTheInitialsAreTyped() {
        var loop = enteringLoop()
        let session = loop.session
        loop.controls.keyDown(.up)

        for _ in 0 ..< Tuning.initialsLen {
            loop.controls.press(.confirm)
            XCTAssertEqual(loop.advance(frame60), 0)
        }

        XCTAssertTrue(loop.isOnHold)
        XCTAssertFalse(loop.isInterrupted)
        XCTAssertEqual(loop.session.state, .highScoreEntry(InitialsEntry()))
        XCTAssertEqual(loop.session.highScores, session.highScores)
    }

    func testTypedInitialsEnterTheScoreAndTheTitleRunsWithoutTheKeysHeld() throws {
        var loop = enteringLoop()
        let points = loop.session.game.score.points
        loop.controls.keyDown(.left)
        loop.controls.press(.confirm)

        XCTAssertEqual(try loop.enterInitials(Initials(typedName)), 0)

        XCTAssertEqual(loop.session.state, .title)
        XCTAssertEqual(loop.session.highScores.entries, [try HighScore(name: Initials(typedName), score: points)])
        XCTAssertFalse(loop.isOnHold)
        XCTAssertEqual(loop.controls.held, [])
        XCTAssertEqual(loop.advance(frame60), 1)
        XCTAssertEqual(loop.session.state, .title)
    }

    func testTypedInitialsOutsideTheEntryDoNothing() throws {
        var loop = titleLoop()
        loop.controls.keyDown(.left)

        XCTAssertNil(try loop.enterInitials(Initials(typedName)))

        XCTAssertEqual(loop.session.state, .title)
        XCTAssertEqual(loop.session.highScores, HighScores())
        XCTAssertEqual(loop.controls.held, [.left])
    }

    func testNewRulesRestartTheTitlesGameWithThem() {
        var loop = titleLoop()

        loop.setRules(Rules(startingLives: StartingLives(ruledLives)))

        XCTAssertEqual(loop.session.game.lives, ruledLives)
    }
}

/// The follow-the-finger steering, applied by the loop.
final class GameLoopSteeringTests: XCTestCase {
    func testTheSteeringDrawsFastInPlay() {
        var loop = steeringLoop()
        loop.steering.steer(towards: aimUp(100))

        loop.advance(Float(Tuning.markerStepTicks) * frame60)

        XCTAssertEqual(loop.session.game.marker.pos, Point(x: 80, y: 119))
        XCTAssertEqual(loop.session.game.stix?.kinds, [.fast])
    }

    func testTheSteeringDrawsSlowWhileSlowIsHeld() {
        var loop = steeringLoop()
        loop.steering.steer(towards: aimUp(100))
        loop.controls.setTouch([.slow])

        for _ in 0 ..< Tuning.slowStepTicks {
            loop.advance(frame60)
        }

        XCTAssertEqual(loop.session.game.marker.pos, Point(x: 80, y: 119))
        XCTAssertEqual(loop.session.game.stix?.kinds, [.slow])
    }

    func testAHeldDirectionWinsOverTheSteering() {
        var loop = steeringLoop()
        loop.steering.steer(towards: aimUp(100))
        loop.controls.keyDown(.left)

        loop.advance(Float(Tuning.markerStepTicks) * frame60)

        XCTAssertEqual(loop.session.game.marker.pos, Point(x: 79, y: 120))
        XCTAssertNil(loop.session.game.stix)
    }

    /// A frame of `Timestep.maxTicksPerFrame` ticks would take the marker two steps with one
    /// direction for the frame: steered afresh each tick, it stops on the target one step away.
    func testTheSteeringIsAskedAtEachTickOfAFrame() {
        var loop = steeringLoop()
        loop.steering.steer(towards: aimUp(119))

        XCTAssertEqual(loop.advance(Float(FixedTimestep.maxTicksPerFrame) * frame60), FixedTimestep.maxTicksPerFrame)

        XCTAssertEqual(loop.session.game.marker.pos, Point(x: 80, y: 119))
    }

    func testOutOfPlayTheSteeringIsLeftAlone() {
        var loop = titleLoop()
        loop.steering.steer(towards: aimUp(0))
        let steering = loop.steering

        loop.advance(frame30)

        XCTAssertEqual(loop.steering, steering)
    }

    func testSuspendingDropsTheAim() {
        var loop = steeringLoop()
        loop.steering.steer(towards: aimUp(100))

        loop.suspend()

        XCTAssertEqual(loop.steering, TouchSteering())
    }
}
