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
