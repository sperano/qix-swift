import XCTest
@testable import QixKit

// The Sparx walking the border and killing the marker through `Game.tick`.

/// Dimensions of the boards: the marker starts at `(width / 2, height)`.
private let width: UInt16 = 8
private let height: UInt16 = 3

/// Lattice steps between the marker's start and the Sparx of
/// `testASparxWalkingIntoAStandingMarkerKills`.
private let gap: UInt16 = 2

/// Ticks a Sparx takes to walk `gap` steps.
private let gapTicks: UInt32 = Tuning.sparxStepTicks * UInt32(gap)

/// A tick on which the marker and the Sparx both step.
private let bothStepTick: UInt32 = Tuning.markerStepTicks * Tuning.sparxStepTicks

/// Height of the board of `testASparxCutOffByAClaimSnapsBackToTheBorder`,
/// tall enough to pen its Qix in `cutColumn`, right of the stix.
private let cutHeight: UInt16 = 6
private let cutColumn: UInt16 = width - 2

/// Where a Sparx is and which way it heads: `Sparx` without its kind.
private struct Walker: Equatable {
    let pos: Point
    let dir: Dir
}

private func sparx(_ pos: Point, _ dir: Dir) -> Sparx {
    Sparx(pos: pos, dir: dir, kind: .normal)
}

/// A game on a free `width x height` board with `sparx` and a short Qix standing
/// in the cell right of the board's centre.
private func sparxGame(_ sparx: [Sparx]) -> Game {
    let (x, y) = (Float(width / 2) + 1.5, Float(height / 2) + 0.5)
    let qix = Qix(
        a: Vec2(x: x - 0.25, y: y),
        b: Vec2(x: x + 0.25, y: y),
        vel: Vec2(),
        spin: 0.0
    )
    return Game(board: Board(width: width, height: height), qix: [qix], sparx: sparx, rng: Rng(seed: gameSeed))
}

/// Ticks `game` `ticks` times with `input` and returns the tick, from
/// one, of each Sparx death raised.
private func sparxDeathTicks(_ game: inout Game, _ input: InputState, _ ticks: UInt32) -> [UInt32] {
    var deaths: [UInt32] = []
    for tick in 1 ... ticks {
        game.tick(input)
        if game.events.contains(.death(.sparx)) {
            deaths.append(tick)
        }
    }
    return deaths
}

final class GameSparxHitsTests: XCTestCase {
    func testANewGameSpawnsTwoSparxAtTheTopCentreHeadingApart() {
        let game = newGame()
        let topCentre = Point(x: Tuning.boardW / 2, y: 0)

        let spawned = game.sparx.map { Walker(pos: $0.pos, dir: $0.dir) }

        XCTAssertEqual(spawned, [Walker(pos: topCentre, dir: .left), Walker(pos: topCentre, dir: .right)])
    }

    func testSparxStepOnceEverySparxStepTicks() throws {
        var game = newGame()
        let topCentre = Point(x: Tuning.boardW / 2, y: 0)

        for tick in 1 ... gapTicks {
            game.tick(InputState())
            let steps = try XCTUnwrap(UInt16(exactly: tick / Tuning.sparxStepTicks))
            let xs = game.sparx.map(\.pos.x)
            XCTAssertEqual(xs, [topCentre.x - steps, topCentre.x + steps])
        }
    }

    func testASparxWalkingIntoAStandingMarkerKills() {
        let start = Point(x: width / 2 + gap, y: height)
        var game = sparxGame([sparx(start, .left)])

        let deaths = sparxDeathTicks(&game, InputState(), gapTicks)

        XCTAssertEqual(game.sparx[0].pos, game.marker.pos)
        XCTAssertEqual(deaths, [gapTicks])
    }

    func testASparxWalkingAwayFromTheMarkerDoesNotKill() {
        let start = Point(x: width / 2 + 1, y: height)
        var game = sparxGame([sparx(start, .right)])

        let deaths = sparxDeathTicks(&game, InputState(), gapTicks)

        XCTAssertEqual(deaths, [])
    }

    func testAMarkerAndASparxSwappingPointsKills() throws {
        // Steps each takes before `bothStepTick`, after which the marker,
        // heading right from (width / 2, height), and the Sparx, heading left, are on
        // neighbouring points and swap them.
        let steps = { (every: UInt32) in try XCTUnwrap(UInt16(exactly: bothStepTick / every - 1)) }
        let markerBefore = try width / 2 + steps(Tuning.markerStepTicks)
        let start = try Point(x: markerBefore + 1 + steps(Tuning.sparxStepTicks), y: height)
        var game = sparxGame([sparx(start, .left)])

        let deaths = sparxDeathTicks(&game, holding(.right), bothStepTick)

        XCTAssertEqual(game.marker.pos, Point(x: markerBefore + 1, y: height))
        XCTAssertEqual(game.sparx[0].pos, Point(x: markerBefore, y: height))
        XCTAssertEqual(deaths, [bothStepTick])
    }

    func testASparxCutOffByAClaimSnapsBackToTheBorder() {
        // The stix goes straight up from (width / 2, cutHeight) and claims the left
        // half, where the Sparx walks.
        let (board, qix) = penned(width, cutHeight, cutColumn)
        let walker = sparx(Point(x: 0, y: 1), .down)
        var game = Game(board: board, qix: [qix], sparx: [walker], rng: Rng(seed: gameSeed))

        draw(&game, .up, .fast, UInt32(cutHeight))

        let cutOff = game.sparx[0]
        XCTAssertEqual(game.marker.state, .onBorder)
        XCTAssert(game.board.cell(x: 0, y: 0).isClaimed, "nothing was claimed")
        XCTAssert(game.board.isBorder(cutOff.pos), "\(cutOff)")
        XCTAssertGreaterThanOrEqual(cutOff.pos.x, width / 2, "\(cutOff)")
    }
}
