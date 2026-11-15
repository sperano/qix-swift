// The state `Session` moves to on the tick a claim earns an extra life: `Event.extraLife` alone
// keeps play going, and must not hide the `Event.levelComplete` raised after it on the same tick.

import XCTest
@testable import QixKit

/// The column of the full board the Qix is penned in, left of every stix the tests draw: each
/// claims the board right of its stix.
private let penColumn: UInt16 = 1

/// Lattice steps left of the marker's start the stix of
/// `testALevelEndingExtraLifeShowsTheCompletedLevel` runs up: far enough that its claim reaches the
/// lowest threshold.
private let bonusStixOffset: UInt32 = 40

/// Holding left without drawing.
private let walkLeft = InputState(dir: .left)

/// A full-size game with no Sparx and its Qix penned in `penColumn`.
private func pennedGame() -> Game {
    var board = Board(width: Tuning.boardW, height: Tuning.boardH)
    let qix = pen(&board, penColumn)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: sessionSeed))
}

/// Draws a stix up from the marker with `session` until the tick that raises an `Event.extraLife`,
/// and checks that one did.
private func drawUpToExtraLife(_ session: inout Session, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0 ..< UInt32(Tuning.boardH) * Tuning.markerStepTicks {
        session.tick(drawUpInput)
        if session.game.events.contains(.extraLife) {
            return
        }
    }
    XCTFail("the stix earned no extra life", file: file, line: line)
}

final class StateExtraLivesTests: XCTestCase {
    func testAnExtraLifeKeepsPlaying() {
        var session = playing(pennedGame())

        drawUpToExtraLife(&session)

        XCTAssertFalse(session.game.isLevelComplete, "the level ended")
        XCTAssertEqual(session.state, .playing)
    }

    func testALevelEndingExtraLifeShowsTheCompletedLevel() {
        var game = pennedGame()
        game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))
        var session = playing(game)
        hold(&session, walkLeft, bonusStixOffset * Tuning.markerStepTicks)

        drawUpToExtraLife(&session)

        guard case let .levelComplete(fraction, bonus, split) = session.game.events.last else {
            return XCTFail("the level did not end: \(session.game.events)")
        }
        XCTAssertEqual(session.state, .levelComplete(fraction: fraction, bonus: bonus, split: split))
    }
}
