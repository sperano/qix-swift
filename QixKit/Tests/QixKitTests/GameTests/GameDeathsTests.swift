import XCTest
@testable import QixKit

/// Dimensions of the boards: the marker starts at `(width / 2, height)`.
private let width: UInt16 = 8
private let height: UInt16 = 6

/// Height of the board the Sparx laps, so that a lap is shorter than the grace period but two are
/// longer.
private let lapHeight: UInt16 = 3

/// Ticks the Sparx takes to walk once round the free `width x lapHeight` board.
private let lapTicks = 2 * (UInt32(width) + UInt32(lapHeight)) * Tuning.sparxStepTicks

/// Lattice steps between the marker's start and the Sparx of `sparxGame`.
private let gap: UInt16 = 2

/// Steps of the stix `dieByFuse` draws up from the border.
private let fuseStixSteps: UInt32 = 2

/// A game on a `width x height` board with the Qix penned in its left column, out of reach of the
/// stix, and no Sparx.
private func fuseGame() -> Game {
    let (board, qix) = penned(width, height, 0)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// A game on a free `width x lapHeight` board with a Sparx `gap` steps right of the marker heading
/// for it, and a short Qix in the top-left cell: the marker never draws, so the Qix never kills.
private func sparxGame() -> Game {
    let sparx = Sparx(pos: Point(x: width / 2 + gap, y: lapHeight), dir: .left, kind: .normal)
    let board = Board(width: width, height: lapHeight)
    return Game(board: board, qix: [qixAt((0, 0))], sparx: [sparx], rng: Rng(seed: gameSeed))
}

/// Ticks the fuse of a stix of `segments` segments takes to light and burn to a marker standing
/// still at its head.
private func burnTicks(_ segments: UInt32) -> UInt32 {
    Tuning.fuseDelayTicks + Tuning.fuseStepTicks * segments
}

/// Ticks `game` `ticks` times with nothing held. `fuse_test.rs` and `game_test/sparx_meter.rs`
/// define their own copy of it in qix-rs; Swift allows one, so they use this one.
func stand(_ game: inout Game, _ ticks: UInt32) {
    hold(&game, InputState(), ticks)
}

/// Waits out the grace period, draws a stix `fuseStixSteps` up from the marker and stands until the
/// fuse kills it.
func dieByFuse(_ game: inout Game) {
    stand(&game, game.graceTicks)
    draw(&game, .up, .fast, fuseStixSteps)
    stand(&game, burnTicks(1))
}

/// Kills the marker of a `fuseGame` by the fuse, then stands and holds the draw button up so that
/// the marker tries its first step of a stix `tick` ticks after the death.
private func tryDrawing(at tick: UInt32) -> Game {
    var game = fuseGame()
    dieByFuse(&game)
    stand(&game, tick - Tuning.markerStepTicks)
    hold(&game, drawing(.up, .fast), Tuning.markerStepTicks)
    return game
}

/// Ticks `game` `ticks` times with nothing held and returns the tick, from one, of each death
/// raised.
private func deathTicks(_ game: inout Game, _ ticks: UInt32) -> [UInt32] {
    (1 ... ticks).filter { _ in
        game.tick(InputState())
        return game.events.contains { event in
            if case .death = event {
                return true
            }
            return false
        }
    }
}

/// Lives, respawning and game over through `Game.tick`.
final class GameDeathsTests: XCTestCase {
    func testANewGameHasEveryLife() {
        let game = newGame()

        XCTAssertEqual(game.lives, Tuning.startingLives)
        XCTAssertFalse(game.isOver)
    }

    func testAFuseDeathTakesALife() {
        var game = fuseGame()

        dieByFuse(&game)

        XCTAssertEqual(game.events, [.death(.fuse)])
        XCTAssertEqual(game.lives, Tuning.startingLives - 1)
    }

    func testASparxDeathTakesALife() {
        var game = sparxGame()

        stand(&game, Tuning.sparxStepTicks * UInt32(gap))

        XCTAssertEqual(game.events, [.death(.sparx)])
        XCTAssertEqual(game.lives, Tuning.startingLives - 1)
    }

    func testAQixDeathTakesALifeAndTheMarkerBackToTheStixStart() {
        var game = bandAndColumn()
        let start = game.marker.pos
        draw(&game, .up, .fast, stepsUp)

        let pastColumn = UInt32(column - start.x) + 1
        let ticks = (1 ... pastColumn * Tuning.markerStepTicks).first { _ in
            game.tick(drawing(.right, .fast))
            return game.events.contains(.death(.qix))
        }

        XCTAssertNotNil(ticks, "the Qix never killed")
        XCTAssertEqual(game.events, [.death(.qix)])
        XCTAssertEqual(game.lives, Tuning.startingLives - 1)
        XCTAssertEqual(game.marker.pos, start)
    }

    func testADeathWhileDrawingClearsTheStixAndRespawnsAtItsStart() {
        var game = fuseGame()
        walk(&game, .right, 1)
        let start = game.marker.pos
        draw(&game, .up, .fast, fuseStixSteps)
        draw(&game, .right, .fast, 1)

        stand(&game, burnTicks(2))

        XCTAssertEqual(game.events, [.death(.fuse)])
        XCTAssertEqual(game.marker.pos, start)
        XCTAssertEqual(game.marker.state, .onBorder)
        XCTAssertNil(game.stix)
        XCTAssertNil(game.fuse)
    }

    func testADeathOnTheBorderLeavesTheMarkerWhereItIs() {
        var game = sparxGame()
        let start = game.marker.pos

        stand(&game, Tuning.sparxStepTicks * UInt32(gap))

        XCTAssertEqual(game.events, [.death(.sparx)])
        XCTAssertEqual(game.marker.pos, start)
        XCTAssertEqual(game.marker.state, .onBorder)
    }

    func testASparxCannotKillDuringTheGracePeriod() {
        XCTAssert((lapTicks ..< 2 * lapTicks).contains(Tuning.respawnGraceTicks))
        var game = sparxGame()
        stand(&game, Tuning.sparxStepTicks * UInt32(gap))
        XCTAssertEqual(game.lives, Tuning.startingLives - 1)

        var deaths = deathTicks(&game, lapTicks)
        XCTAssertEqual(game.sparx[0].pos, game.marker.pos, "no lap")
        XCTAssertEqual(deaths, [])

        deaths = deathTicks(&game, lapTicks)
        XCTAssertEqual(deaths, [lapTicks], "the grace period did not end")
    }

    func testTheMarkerCannotDrawDuringTheGracePeriod() {
        var game = fuseGame()
        dieByFuse(&game)
        let start = game.marker.pos

        for _ in 0 ..< Tuning.respawnGraceTicks {
            game.tick(drawing(.up, .fast))
            XCTAssertEqual(game.marker.pos, start)
            XCTAssertNil(game.stix)
        }
        hold(&game, drawing(.up, .fast), Tuning.markerStepTicks)

        XCTAssertEqual(game.marker.state, .drawing)
    }

    func testTheGracePeriodEndsAfterItsLastTick() {
        let last = tryDrawing(at: Tuning.respawnGraceTicks)
        XCTAssertEqual(last.graceTicks, 0)
        XCTAssertEqual(last.marker.state, .onBorder, "drew on the last tick of the grace period")

        let after = tryDrawing(at: Tuning.respawnGraceTicks + 1)
        XCTAssertEqual(
            after.marker.state,
            .drawing,
            "could not draw on the first tick after the grace period"
        )
    }

    func testTheMarkerWalksTheBorderDuringTheGracePeriod() {
        var game = fuseGame()
        dieByFuse(&game)
        let start = game.marker.pos

        walk(&game, .right, 1)

        XCTAssert(game.graceTicks > 0, "the grace period ended")
        XCTAssertEqual(game.marker.pos, Point(x: start.x + 1, y: start.y))
    }

    func testLosingTheLastLifeRaisesGameOver() {
        var game = fuseGame()
        for lives in (1 ..< Tuning.startingLives).reversed() {
            dieByFuse(&game)
            XCTAssertEqual(game.events, [.death(.fuse)])
            XCTAssertEqual(game.lives, lives)
        }

        dieByFuse(&game)

        let gameOver: [Event] = [.death(.fuse), .gameOver]
        XCTAssertEqual(game.events, gameOver)
        XCTAssertEqual(game.lives, 0)
        XCTAssert(game.isOver)
        XCTAssertEqual(game.graceTicks, 0, "a grace period after game over")
    }

    func testAGameOverNoLongerTicks() {
        var game = fuseGame()
        for _ in 0 ..< Tuning.startingLives {
            dieByFuse(&game)
        }
        let (ticks, marker, qix) = (game.ticks, game.marker, game.qix)

        hold(&game, holding(.right), Tuning.markerStepTicks)

        XCTAssertEqual(game.ticks, ticks)
        XCTAssertEqual(game.events, [])
        XCTAssertEqual(game.marker, marker)
        XCTAssertEqual(game.qix, qix)
    }
}
