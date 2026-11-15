import XCTest
@testable import QixKit

// Super Sparx chasing the marker along the stix through `Game.tick`.

/// Dimensions of the board: the marker starts at `(width / 2, height)`.
private let width: UInt16 = 8
private let height: UInt16 = 6

/// The column the Qix is penned in, clear of the stix.
private let penColumn: UInt16 = 1

/// Steps of the stix drawn up from the marker's start: it stops short of
/// the top edge, so it stays open.
private let stixSteps: UInt16 = height - 2

/// Lattice steps between the marker's start and the Sparx heading for it
/// along the bottom edge.
private let gap: UInt16 = 2

/// Ticks the tests watch: long enough for a Sparx to reach the stix's
/// start and walk all of it, short of the fuse.
private let watchTicks: UInt32 =
    (UInt32(gap) + 1) * Tuning.sparxStepTicks + (UInt32(stixSteps) + 1) * Tuning.superSparxStepTicks

/// Where the marker starts, and the stix with it.
private let start = Point(x: width / 2, y: height)

/// Where the marker stands at the head of the stix.
private let head = Point(x: width / 2, y: height - stixSteps)

/// Steps of the stix the fuse burns in
/// `testASparxOnTheStixSnapsToTheBorderOnAFuseDeath`, drawn
/// straight up: two of its lattice points lie between its start and its
/// head.
private let fuseStixSteps: UInt32 = 3

/// Width of that test's board: the bottom edge right of the marker's start
/// is long enough for the Sparx to reach the stix late.
private let fuseWidth: UInt16 = 32

/// The tick the fuse reaches the head: the stix drawn fast, the fuse's
/// delay, then one fuse step for the stix's one segment.
private let fuseDeathTick: UInt32 =
    fuseStixSteps * Tuning.markerStepTicks + Tuning.fuseDelayTicks + Tuning.fuseStepTicks

/// The tick the Sparx steps onto the stix point after the start: it is on
/// the last point before the head on `fuseDeathTick`, a step short of
/// the marker.
private let ontoStixTick: UInt32 = fuseDeathTick - (fuseStixSteps - 2) * Tuning.superSparxStepTicks

/// Lattice steps between the marker's start and the Sparx: it reaches the
/// stix's start on its last border step before `ontoStixTick`.
private let fuseGap = UInt16((ontoStixTick - 1) / Tuning.sparxStepTicks)

/// A Sparx of `kind` `gap` steps right of the marker on the bottom
/// edge, heading for it.
private func sparx(_ kind: SparxKind) -> Sparx {
    Sparx(pos: Point(x: width / 2 + gap, y: height), dir: .left, kind: kind)
}

/// A game on a `penned` board with one Sparx of `kind`.
private func gameWith(_ kind: SparxKind) -> Game {
    let (board, qix) = penned(width, height, penColumn)
    return Game(board: board, qix: [qix], sparx: [sparx(kind)], rng: Rng(seed: gameSeed))
}

/// What one tick of `watch` saw.
private struct Seen {
    /// The tick, from one.
    let tick: UInt32
    /// Where the Sparx is after it.
    let pos: Point
    /// The Sparx killed the marker on it.
    let sparxDeath: Bool
}

/// A point of the stix the Sparx stepped onto, and the tick it did.
private struct StixStep: Equatable {
    let tick: UInt32
    let pos: Point
}

/// Draws `stixSteps` up from `start`, then stands for the rest of
/// `watchTicks`, recording every tick.
private func watch(_ game: inout Game) -> [Seen] {
    let input = { (tick: UInt32) in
        let isDrawing = tick <= UInt32(stixSteps) * Tuning.superSparxStepTicks
        return InputState(dir: isDrawing ? .up : nil, fast: isDrawing)
    }
    return (1 ... watchTicks).map { tick in
        game.tick(input(tick))
        return Seen(
            tick: tick,
            pos: game.sparx[0].pos,
            sparxDeath: game.events.contains(.death(.sparx))
        )
    }
}

/// The points of the stix other than its start the Sparx of `seen`
/// stepped onto, with the tick it did.
private func onTheStix(_ seen: [Seen]) -> [StixStep] {
    var steps: [StixStep] = []
    for seen in seen where seen.pos.x == start.x && (head.y ..< start.y).contains(seen.pos.y) {
        if steps.last?.pos != seen.pos {
            steps.append(StixStep(tick: seen.tick, pos: seen.pos))
        }
    }
    return steps
}

/// Whether `event` is `Event.death`.
private func isDeath(_ event: Event) -> Bool {
    if case .death = event {
        return true
    }
    return false
}

final class GameSuperSparxTests: XCTestCase {
    func testASuperSparxEntersTheStixAndKillsTheMarkerAtItsHead() throws {
        var game = gameWith(.super)

        let seen = watch(&game)

        let chase = onTheStix(seen)
        let points = chase.map(\.pos)
        let expected = (head.y + 1 ..< start.y).reversed().map { Point(x: start.x, y: $0) }
        XCTAssertEqual(points, expected, "\(seen)")
        let death = seen.filter(\.sparxDeath)
        XCTAssertEqual(death.count, 1, "\(seen)")
        let lastTick = try XCTUnwrap(chase.last?.tick, "\(seen)")
        let deathTick = try XCTUnwrap(death.first?.tick, "\(seen)")
        XCTAssertEqual(deathTick, lastTick + Tuning.superSparxStepTicks)
    }

    func testASuperSparxStepsAlongTheStixEverySuperSparxStepTicks() {
        var game = gameWith(.super)

        let chase = onTheStix(watch(&game))

        XCTAssertGreaterThan(chase.count, 1, "\(chase)")
        for pair in zip(chase, chase.dropFirst()) {
            XCTAssertEqual(pair.1.tick - pair.0.tick, Tuning.superSparxStepTicks, "\(chase)")
        }
    }

    func testANormalSparxDoesNotEnterTheStix() {
        var game = gameWith(.normal)

        let seen = watch(&game)

        XCTAssert(seen.contains { $0.pos.x < start.x }, "\(seen)")
        XCTAssertEqual(onTheStix(seen), [], "\(seen)")
        XCTAssert(seen.allSatisfy { !$0.sparxDeath }, "\(seen)")
        XCTAssert(seen.allSatisfy { game.board.isBorder($0.pos) }, "\(seen)")
    }

    func testASparxOnAClearedStixSnapsToTheNearestBorderPoint() throws {
        var game = gameWith(.super)

        let seen = watch(&game)

        let death = try XCTUnwrap(seen.first { $0.sparxDeath }, "no death")
        XCTAssertNil(game.stix)
        // The nearest border point to the head is beside the Qix's pen wall.
        XCTAssertEqual(death.pos, Point(x: penColumn + 2, y: head.y), "\(seen)")
    }

    func testASparxOnAClosedStixEndsOnTheBorder() throws {
        var game = gameWith(.super)

        draw(&game, .up, .fast, UInt32(height - 1))
        let chaser = game.sparx[0]
        let stix = try XCTUnwrap(game.stix, "the stix closed early")
        XCTAssert(chaser.chasesAlong(stix) && chaser.pos != start, "\(chaser)")

        // The last step reaches the top edge and turns the stix into border.
        var events: [Event] = []
        for _ in 0 ..< Tuning.markerStepTicks {
            game.tick(drawing(.up, .fast))
            events.append(contentsOf: game.events)
        }

        let sparx = game.sparx[0]
        XCTAssertNil(game.stix)
        XCTAssert(game.board.isBorder(sparx.pos), "\(sparx)")
        XCTAssertEqual(sparx.pos.x, start.x, "\(sparx)")
        XCTAssert(events.allSatisfy { !isDeath($0) }, "\(events)")
    }

    func testASparxOnTheStixSnapsToTheBorderOnAQixDeath() throws {
        let start = bandAndColumn().marker.pos
        let chaser = Sparx(pos: Point(x: start.x + 1, y: start.y), dir: .left, kind: .super)
        var game = bandAndColumnWith([chaser])
        draw(&game, .up, .fast, stepsUp)

        // Drawn fast, the marker keeps the chaser a step behind it until the
        // stix crosses the Qix's column.
        let pastColumn = UInt32(column - start.x) + 1
        var beforeDeath: Sparx?
        for _ in 1 ... pastColumn * Tuning.markerStepTicks {
            let before = game.sparx[0]
            game.tick(drawing(.right, .fast))
            if game.events.contains(.death(.qix)) {
                beforeDeath = before
                break
            }
        }

        let before = try XCTUnwrap(beforeDeath, "the Qix never killed")
        XCTAssertEqual(game.events, [.death(.qix)])
        XCTAssertFalse(game.board.isBorder(before.pos), "\(before)")
        let sparx = game.sparx[0]
        XCTAssert(game.board.isBorder(sparx.pos), "\(sparx)")
    }

    func testASparxOnTheStixSnapsToTheBorderOnAFuseDeath() throws {
        let (board, qix) = penned(fuseWidth, height, penColumn)
        let chaser = Sparx(pos: Point(x: fuseWidth / 2 + fuseGap, y: height), dir: .left, kind: .super)
        var game = Game(board: board, qix: [qix], sparx: [chaser], rng: Rng(seed: gameSeed))
        draw(&game, .up, .fast, fuseStixSteps)
        let standing = fuseDeathTick - 1 - fuseStixSteps * Tuning.markerStepTicks
        hold(&game, InputState(), standing)

        let before = game.sparx[0]
        let stix = try XCTUnwrap(game.stix, "the marker died before the fuse")
        XCTAssert(before.chasesAlong(stix), "\(before)")
        XCTAssertFalse(game.board.isBorder(before.pos), "\(before)")
        game.tick(InputState())

        XCTAssertEqual(game.events, [.death(.fuse)])
        let sparx = game.sparx[0]
        XCTAssert(game.board.isBorder(sparx.pos), "\(sparx)")
    }
}
