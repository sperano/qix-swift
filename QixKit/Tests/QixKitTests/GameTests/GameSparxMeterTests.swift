import XCTest
@testable import QixKit

/// Dimensions of the board: the marker starts at `(width / 2, height)`.
private let width: UInt16 = 8
private let height: UInt16 = 3

/// Ticks of each countdown of the meter of `meterGame`.
private let length: UInt32 = 2

/// Lattice steps between the marker's start and the Sparx of `meterGame` heading for it.
private let gap: UInt16 = 2

/// The tick, from one, the Sparx of `meterGame` reaches the standing marker: after both expiries of
/// a meter of `length`.
private let deathTick: UInt32 = Tuning.sparxStepTicks * UInt32(gap)

/// Where the marker starts, and where the Sparx of `meterGame` kills it on `deathTick`.
private let markerStart = Point(x: width / 2, y: height)

/// The Sparx `gap` steps right of the marker, heading for it.
private func killer() -> Sparx {
    Sparx(pos: Point(x: width / 2 + gap, y: height), dir: .left, kind: .normal)
}

/// A game on a free `width x height` board with a meter of `length`, a short Qix in the top-left
/// cell (the marker never draws, so the Qix never kills) and `sparx` as the level's Sparx.
private func gameWith(_ sparx: [Sparx], _ length: UInt32) -> Game {
    let board = Board(width: width, height: height)
    var game = Game(board: board, qix: [qixAt((0, 0))], sparx: sparx, rng: Rng(seed: gameSeed))
    game.setSparxMeter(SparxMeter(length: length))
    return game
}

/// A game of `gameWith` whose only level Sparx is the `killer`.
private func meterGame(_ length: UInt32) -> Game {
    gameWith([killer()], length)
}

private func kinds(_ game: Game) -> [SparxKind] {
    game.sparx.map(\.kind)
}

/// The Sparx meter releasing Sparx and turning them Super through `Game.tick`.
final class GameSparxMeterTests: XCTestCase {
    func testANewGameStartsWithAFullMeter() {
        XCTAssertEqual(newGame().sparxMeter, SparxMeter(length: Tuning.sparxMeterTicks))
    }

    func testTheMeterCountsDownEveryTick() {
        var game = newGame()

        stand(&game, 1)

        XCTAssertEqual(game.sparxMeter.remaining, Tuning.sparxMeterTicks - 1)
    }

    func testNothingIsReleasedBeforeTheFirstExpiry() {
        var game = meterGame(length)

        stand(&game, length - 1)

        XCTAssertEqual(game.sparx.count, 1)
    }

    func testTheFirstExpiryReleasesTheExtraSparxAtTheTopCentre() {
        var game = meterGame(length)

        stand(&game, length)

        let extra = Array(game.sparx[1...])
        XCTAssertEqual(extra.count, Tuning.extraSparx)
        let topCentre = Point(x: width / 2, y: 0)
        XCTAssert(extra.allSatisfy { $0.pos == topCentre })
        XCTAssert(extra.allSatisfy { $0.kind == .normal })
        XCTAssertEqual(extra.map(\.dir), [.left, .right])
        XCTAssertEqual(game.sparxMeter.nextExpiry, .super)
    }

    func testTheSecondExpiryTurnsEverySparxSuper() {
        var game = meterGame(length)
        stand(&game, 2 * length - 1)
        XCTAssert(kinds(game).allSatisfy { $0 == .normal })

        stand(&game, 1)

        XCTAssertEqual(kinds(game), Array(repeating: .super, count: 1 + Tuning.extraSparx))
        XCTAssertNil(game.sparxMeter.nextExpiry)
    }

    func testADeathResetsTheMeterAndUndoesItsExpiries() {
        var game = meterGame(length)
        stand(&game, deathTick - 1)
        XCTAssertEqual(kinds(game), Array(repeating: .super, count: 1 + Tuning.extraSparx))

        stand(&game, 1)

        XCTAssertEqual(game.events, [.death(.sparx)])
        XCTAssertEqual(game.sparxMeter, SparxMeter(length: length))
        XCTAssertEqual(kinds(game), [.normal])
        XCTAssertEqual(game.sparx[0].pos, markerStart)
    }

    func testADeathGivesEveryLevelSparxBackItsOwnStartingKind() {
        let far = Sparx(pos: Point(x: 0, y: 0), dir: .down, kind: .super)
        var game = gameWith([killer(), far], length)
        stand(&game, deathTick - 1)
        XCTAssertEqual(kinds(game), Array(repeating: .super, count: 2 + Tuning.extraSparx))

        stand(&game, 1)

        XCTAssertEqual(game.events, [.death(.sparx)])
        XCTAssertEqual(kinds(game), [.normal, .super])
        XCTAssertEqual(game.sparx[0].pos, markerStart)
        // Down the left border, one step per step of the killer.
        XCTAssertEqual(game.sparx[1].pos, Point(x: 0, y: gap))
    }

    func testADeathBeforeTheFirstExpiryFillsTheMeter() {
        let length = 2 * deathTick
        var game = meterGame(length)

        stand(&game, deathTick)

        XCTAssertEqual(game.events, [.death(.sparx)])
        XCTAssertEqual(game.sparxMeter, SparxMeter(length: length))
    }

    func testTheMeterRunsAgainAfterADeath() {
        var game = meterGame(length)
        stand(&game, deathTick)

        stand(&game, length)

        XCTAssertEqual(game.sparx.count, 1 + Tuning.extraSparx)
    }
}
