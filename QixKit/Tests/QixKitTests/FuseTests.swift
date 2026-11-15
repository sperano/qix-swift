// The fuse lighting, burning and going out through `Game.tick`.

import XCTest
@testable import QixKit

/// Seed of every game the tests play.
private let seed: UInt64 = 1_196

/// Dimensions of the boards: the marker starts at `(width / 2, height)`.
private let width: UInt16 = 8
private let height: UInt16 = 5

/// Ticks a stix step holds its direction before the marker moves.
private let heldTicks: UInt32 = Tuning.markerStepTicks - 1

/// Index of the head of a stix drawn up, right, then up.
private let upRightUpHead = 3

/// Index of the head of `spiralIntoADeadEnd`'s stix.
private let spiralHead = 5

/// A game on a `width x height` board with the Qix penned in its left column, out of reach of the
/// stix, and no Sparx.
private func fuseGame() -> Game {
    let (board, qix) = penned(width, height, 0)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: seed))
}

/// A game drawing a stix up 2 steps, right 2, then up 1.
private func upRightUp() -> Game {
    var game = fuseGame()
    draw(&game, .up, .fast, 2)
    draw(&game, .right, .fast, 2)
    draw(&game, .up, .fast, 1)
    return game
}

/// Draws a stix that spirals in until the marker, at `(5, 2)`, is boxed in by it on every side.
private func spiralIntoADeadEnd(_ game: inout Game) {
    draw(&game, .up, .fast, 4)
    draw(&game, .right, .fast, 2)
    draw(&game, .down, .fast, 2)
    draw(&game, .left, .fast, 1)
    draw(&game, .up, .fast, 1)
}

private func fuseAt(_ pos: Int) -> Fuse? {
    Fuse(pos: pos)
}

private func fuseDeath(_ game: Game) -> Bool {
    game.events.contains(.death(.fuse))
}

final class FuseTests: XCTestCase {
    func testTheFuseIsOutWhileTheMarkerDrawsSteadily() {
        var game = fuseGame()
        for _ in 0 ..< height - 1 {
            draw(&game, .up, .fast, 1)
            XCTAssertNil(game.fuse)
        }
    }

    func testTheFuseLightsAtTheStixStartAfterTheDelay() {
        var game = fuseGame()
        draw(&game, .up, .fast, 2)
        stand(&game, Tuning.fuseDelayTicks - 1)
        XCTAssertNil(game.fuse)
        stand(&game, 1)
        XCTAssertEqual(game.fuse, fuseAt(0))
    }

    func testAMarkerOnTheBorderNeverLightsTheFuse() {
        var game = fuseGame()
        stand(&game, Tuning.fuseDelayTicks * 2)
        XCTAssertNil(game.fuse)
    }

    func testTheLitFuseBurnsOneSegmentEveryStepTicks() throws {
        var game = upRightUp()
        XCTAssertEqual(try XCTUnwrap(game.stix).points.count, upRightUpHead + 1)
        stand(&game, Tuning.fuseDelayTicks)
        // The fuse reaching the head kills and goes out: see
        // `testTheFuseReachingTheMarkerKillsOnceAndGoesOut`.
        for pos in 1 ..< upRightUpHead {
            stand(&game, Tuning.fuseStepTicks - 1)
            XCTAssertEqual(game.fuse, fuseAt(pos - 1))
            XCTAssertFalse(fuseDeath(game))
            stand(&game, 1)
            XCTAssertEqual(game.fuse, fuseAt(pos))
        }
    }

    func testTheFuseReachingTheMarkerKillsOnceAndGoesOut() {
        var game = upRightUp()
        let burn = Tuning.fuseDelayTicks + Tuning.fuseStepTicks * UInt32(upRightUpHead)
        let watch = burn + Tuning.fuseStepTicks
        let deaths: [UInt32] = (1 ... watch).filter { _ in
            game.tick(InputState())
            return fuseDeath(game)
        }
        XCTAssertEqual(deaths, [burn])
        XCTAssertNil(game.fuse)
    }

    func testStandingAgainstAnIllegalStepLightsTheFuse() {
        var game = fuseGame()
        draw(&game, .up, .fast, 2)
        let pos = game.marker.pos
        hold(&game, drawing(.down, .fast), Tuning.fuseDelayTicks)
        XCTAssertEqual(game.marker.pos, pos)
        XCTAssertEqual(game.fuse, fuseAt(0))
    }

    func testAStepPutsTheFuseOutAndTheNextOneLightsAtTheStart() {
        var game = upRightUp()
        stand(&game, Tuning.fuseDelayTicks + Tuning.fuseStepTicks)
        XCTAssertEqual(game.fuse, fuseAt(1))
        draw(&game, .up, .fast, 1)
        XCTAssertNil(game.fuse)
        stand(&game, Tuning.fuseDelayTicks - 1)
        XCTAssertNil(game.fuse)
        stand(&game, 1)
        XCTAssertEqual(game.fuse, fuseAt(0))
    }

    func testAStepWhileTheFuseIsOutRestartsTheDelay() {
        var game = fuseGame()
        draw(&game, .up, .fast, 2)
        // The ticks a step holds its direction before the marker moves count
        // as standing. Leave room for those of the last step and the next one,
        // so the fuse stays out through the step even if the last step did not
        // restart the delay.
        stand(&game, Tuning.fuseDelayTicks - 1 - 2 * heldTicks)
        draw(&game, .up, .fast, 1)
        XCTAssertNil(game.fuse)
        stand(&game, Tuning.fuseDelayTicks - 1)
        XCTAssertNil(game.fuse)
        stand(&game, 1)
        XCTAssertEqual(game.fuse, fuseAt(0))
    }

    func testClosingTheStixPutsTheFuseOut() {
        var game = fuseGame()
        draw(&game, .up, .fast, 2)
        stand(&game, Tuning.fuseDelayTicks)
        draw(&game, .up, .fast, UInt32(height) - 2)
        XCTAssertEqual(game.marker.state, .onBorder)
        XCTAssertNil(game.fuse)
        stand(&game, Tuning.fuseDelayTicks)
        XCTAssertNil(game.fuse)
    }

    func testADeadEndLightsTheFuseAtOnce() throws {
        var game = fuseGame()
        spiralIntoADeadEnd(&game)
        XCTAssertEqual(game.marker.pos, Point(x: 5, y: 2))
        let stix = try XCTUnwrap(game.stix)
        XCTAssert(legalMoves(game.marker, stix, game.board).isEmpty)
        XCTAssertEqual(stix.points.count, spiralHead + 1)
        XCTAssertEqual(game.fuse, fuseAt(0))
    }

    func testTheFuseIsOutOneStepBeforeTheDeadEnd() {
        var game = fuseGame()
        draw(&game, .up, .fast, 4)
        draw(&game, .right, .fast, 2)
        draw(&game, .down, .fast, 2)
        draw(&game, .left, .fast, 1)
        XCTAssertNil(game.fuse)
    }

    func testTheFuseLitByADeadEndBurnsToTheMarker() {
        var game = fuseGame()
        spiralIntoADeadEnd(&game)
        let burn = Tuning.fuseStepTicks * UInt32(spiralHead)
        stand(&game, burn - 1)
        XCTAssertFalse(fuseDeath(game))
        stand(&game, 1)
        XCTAssert(fuseDeath(game))
    }

    func testLightingALitFuseLeavesItWhereItBurntTo() {
        var timer = FuseTimer()
        timer.light()
        for _ in 0 ..< Tuning.fuseStepTicks {
            timer.stand(upRightUpHead)
        }
        timer.light()
        XCTAssertEqual(timer.fuse, fuseAt(1))
    }
}
