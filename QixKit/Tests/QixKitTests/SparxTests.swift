import Testing
import XCTest
@testable import QixKit

/// Dimensions of the small board most tests use.
private let width: UInt16 = 6
private let height: UInt16 = 4

/// Seed of the generator the tests draw from.
private let seed: UInt64 = 1_195

/// Steps the random-turn test draws, enough to see every way out.
private let draws = 100

/// Width of the board of the level spawn tests, and the Sparx they
/// spawn: three pairs, the last one short, spread at quarters of it.
private let levelWidth: UInt16 = 12
private let levelSparx = 5
private let levelSparxX: [UInt16] = [3, 6, 9]

/// Steps the stix-walking test takes: one past the stix's two, to see the Sparx stay at the head.
private let stixWalkSteps = 3

/// Length of the stix the stix tests walk.
private let stixLength: UInt16 = 2

private let claimed = Cell.claimed(.fast)

/// Where a Sparx is and where it heads, which tuples cannot compare.
private struct Heading: Equatable {
    let pos: Point
    let dir: Dir

    init(_ pos: Point, _ dir: Dir) {
        self.pos = pos
        self.dir = dir
    }

    init(_ sparx: Sparx) {
        self.init(sparx.pos, sparx.dir)
    }
}

/// A `Sparx.normal` one at `pos` heading `dir` (`sparx` in qix-rs, which the tests' own Sparx
/// variables would shadow).
private func normalSparx(_ pos: Point, _ dir: Dir) -> Sparx {
    Sparx(pos: pos, dir: dir, kind: .normal)
}

/// A `width x height` board with the cells `claimedCells` lists claimed.
private func boardWith(_ claimedCells: [(UInt16, UInt16)]) -> Board {
    var board = Board(width: width, height: height)
    for (x, y) in claimedCells {
        board.setCell(x: x, y: y, to: claimed)
    }
    return board
}

/// The points a Sparx steps through on `board`, `steps` of them, starting
/// with the one after its own.
private func walk(_ board: Board, _ start: Sparx, _ steps: Int) -> [Point] {
    var sparx = start
    var rng = Rng(seed: seed)
    return (0 ..< steps).map { _ in
        sparx.step(board, &rng)
        return sparx.pos
    }
}

/// A fast stix up from the bottom edge at `x`, `steps` long.
private func stixUp(_ x: UInt16, _ steps: UInt16) -> Stix {
    var stix = Stix(start: Point(x: x, y: height))
    for y in (height - steps ..< height).reversed() {
        stix.push(Point(x: x, y: y), .fast)
    }
    return stix
}

final class SparxTests: XCTestCase {
    func testAPairSpawnsAtTheTopCentreHeadingOppositeWays() {
        let pair = Sparx.spawnPair(Board(width: width, height: height))

        XCTAssertEqual(pair.count, 2)
        let (left, right) = (pair[0], pair[1])
        XCTAssertEqual(left.pos, Point(x: width / 2, y: 0))
        XCTAssertEqual(right.pos, left.pos)
        XCTAssertEqual(left.dir, .left)
        XCTAssertEqual(right.dir, .right)
        XCTAssertEqual(left.kind, .normal)
        XCTAssertEqual(right.kind, .normal)
    }

    func testAPairSpawnsOnTheBorderNearestTheTopCentre() {
        let board = boardWith([(2, 0), (3, 0), (2, 1), (3, 1)])

        let pair = Sparx.spawnPair(board)
        let (left, right) = (pair[0], pair[1])

        // (2, 0) and (4, 0) are one step away; (2, 0) comes first.
        XCTAssertFalse(board.isBorder(Point(x: width / 2, y: 0)))
        XCTAssertEqual(left.pos, Point(x: width / 2 - 1, y: 0))
        XCTAssertEqual(right.pos, left.pos)
    }

    func testWalksTheFreshBorderInALoopBothWays() {
        let board = Board(width: width, height: height)
        let perimeter = 2 * Int(width + height)

        for start in Sparx.spawnPair(board) {
            let points = walk(board, start, perimeter)

            XCTAssert(points.allSatisfy { board.isBorder($0) })
            XCTAssertEqual(Set(points).count, perimeter)
            XCTAssertEqual(points.last, start.pos)
        }
    }

    func testEachWayRoundVisitsTheOtherWaySPointsInReverse() {
        let board = Board(width: width, height: height)
        let perimeter = 2 * Int(width + height)
        let pair = Sparx.spawnPair(board)
        let (left, right) = (pair[0], pair[1])

        let leftwards = Array(walk(board, left, perimeter - 1).reversed())

        XCTAssertEqual(leftwards, walk(board, right, perimeter - 1))
    }

    func testTurnsACornerRatherThanReversing() {
        var sparx = normalSparx(Point(x: 0, y: 0), .left)

        var rng = Rng(seed: seed)
        sparx.step(Board(width: width, height: height), &rng)

        XCTAssertEqual(Heading(sparx), Heading(Point(x: 0, y: 1), .down))
    }

    func testGoesStraightThroughAJunction() {
        // Diagonal claimed cells meet at (2, 2), where four border edges meet.
        let board = boardWith([(1, 1), (2, 2)])
        let junction = Point(x: 2, y: 2)
        XCTAssertEqual(board.borderNeighbours(junction).count, Dir.all.count)

        for dir in Dir.all {
            var sparx = normalSparx(junction, dir)
            var rng = Rng(seed: seed)
            sparx.step(board, &rng)
            XCTAssertEqual(sparx.pos, dir.step(junction))
            XCTAssertEqual(sparx.dir, dir)
        }
    }

    func testTurnsARandomWayWhenItCannotGoStraight() {
        // On the top edge, heading down: left and right are the ways out.
        let board = Board(width: width, height: height)
        let start = Point(x: width / 2, y: 0)
        var rng = Rng(seed: seed)

        let dirs = Set((0 ..< draws).map { _ -> Dir in
            var sparx = normalSparx(start, .down)
            sparx.step(board, &rng)
            return sparx.dir
        })

        XCTAssertEqual(dirs, [.left, .right])
    }

    func testTurnPrefersStraightThenSidewaysAndReversesOnlyAtADeadEnd() {
        var rng = Rng(seed: seed)

        let straight = Sparx.turn(.right, [.left, .up, .right], &rng)
        let sideways = Sparx.turn(.right, [.left, .up], &rng)
        let deadEnd = Sparx.turn(.right, [.left], &rng)
        let isolated = Sparx.turn(.right, [], &rng)

        XCTAssertEqual(straight, .right)
        XCTAssertEqual(sideways, .up)
        XCTAssertEqual(deadEnd, .left)
        XCTAssertNil(isolated)
    }

    func testAChoiceFreeTurnDrawsNothing() {
        var rng = Rng(seed: seed)

        _ = Sparx.turn(.right, [.left, .up], &rng)

        XCTAssertEqual(rng, Rng(seed: seed))
    }

    func testSnapsToTheNearestBorderPointAfterAClaim() {
        // A stix straight down column 2 claims the cells left of it.
        var board = Board(width: width, height: height)
        var stix = Stix(start: Point(x: 2, y: 0))
        stix.push(Point(x: 2, y: height), .fast)
        board.closeStix(stix, [qixAt((width - 1, height / 2))])
        var cutOff = normalSparx(Point(x: 0, y: 1), .down)

        cutOff.snapToBorder(board)

        XCTAssertEqual(cutOff.pos, Point(x: 2, y: 1))
        XCTAssertEqual(cutOff.dir, .down)
    }

    func testASparxStillOnTheBorderDoesNotSnap() {
        let board = boardWith([(0, 0)])
        let onBorder = normalSparx(Point(x: width, y: 1), .up)
        var snapped = onBorder

        snapped.snapToBorder(board)

        XCTAssertEqual(snapped, onBorder)
    }

    func testTheNearestBorderPointIsTheFirstOfEquallyNearOnes() {
        // (1, 0) is two steps from both (3, 0) and (1, 2).
        let board = boardWith([(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)])

        let nearest = nearestBorderPoint(board, Point(x: 1, y: 0))

        XCTAssertEqual(nearest, Point(x: 3, y: 0))
    }

    func testABoardWithNoBorderHasNoNearestBorderPoint() {
        var board = Board(width: 1, height: 1)
        board.setCell(x: 0, y: 0, to: claimed)

        XCTAssertNil(nearestBorderPoint(board, Point(x: 0, y: 0)))
    }

    func testASparxWithNoBorderEdgeStaysPut() {
        var board = Board(width: 1, height: 1)
        board.setCell(x: 0, y: 0, to: claimed)
        var sparx = normalSparx(Point(x: 0, y: 0), .left)
        var rng = Rng(seed: seed)

        sparx.step(board, &rng)

        XCTAssertEqual(Heading(sparx), Heading(Point(x: 0, y: 0), .left))
    }

    func testASparxSteppingOntoTheMarkerHitsIt() {
        let marker = Point(x: 2, y: 0)
        let sparx = normalSparx(marker, .left)

        XCTAssert(sparx.hitsMarker(Point(x: 3, y: 0), marker, marker))
    }

    func testTheMarkerSteppingOntoASparxHitsIt() {
        let at = Point(x: 2, y: 0)
        let sparx = normalSparx(at, .left)

        XCTAssert(sparx.hitsMarker(at, Point(x: 1, y: 0), at))
    }

    func testASparxAndTheMarkerSwappingPointsHit() {
        let (first, second) = (Point(x: 1, y: 0), Point(x: 2, y: 0))
        let sparx = normalSparx(first, .left)

        XCTAssert(sparx.hitsMarker(second, first, second))
    }

    func testASparxFollowingTheMarkerDoesNotHitIt() {
        // The marker goes from 2 to 3 while the Sparx goes from 1 to 2.
        let sparx = normalSparx(Point(x: 2, y: 0), .right)

        XCTAssertFalse(sparx.hitsMarker(Point(x: 1, y: 0), Point(x: 2, y: 0), Point(x: 3, y: 0)))
    }

    func testASparxNextToTheMarkerDoesNotHitIt() {
        let sparx = normalSparx(Point(x: 3, y: 0), .right)
        let marker = Point(x: 2, y: 0)

        XCTAssertFalse(sparx.hitsMarker(Point(x: 3, y: 0), marker, marker))
    }

    func testSpawnAtTopAlternatesLeftAndRightFromThePairPoint() {
        let board = boardWith([(width / 2 - 1, 0), (width / 2, 0)])
        let pair = Sparx.spawnPair(board)[0]

        let spawned = Sparx.spawnAtTop(board, 3)

        XCTAssert(spawned.allSatisfy { $0.pos == pair.pos })
        XCTAssert(spawned.allSatisfy { $0.kind == .normal })
        XCTAssertEqual(spawned.map(\.dir), [.left, .right, .left])
    }

    func testOnlyASuperSparxChasesAlongTheStix() {
        let stix = stixUp(width / 2, stixLength)
        let normal = normalSparx(stix.start, .left)
        var chaser = normal
        chaser.kind = .super

        XCTAssertFalse(normal.chasesAlong(stix))
        XCTAssert(chaser.chasesAlong(stix))
    }

    func testASuperSparxOffTheStixDoesNotChaseAlongIt() {
        let stix = stixUp(width / 2, stixLength)
        var chaser = normalSparx(Point(x: width / 2 + 1, y: height), .left)
        chaser.kind = .super

        XCTAssertFalse(chaser.chasesAlong(stix))
    }

    func testASparxStepsAlongTheStixToItsHeadAndStaysThere() {
        let stix = stixUp(width / 2, stixLength)
        var chaser = normalSparx(stix.start, .left)

        let points = (0 ..< stixWalkSteps).map { _ -> Point in
            chaser.stepAlongStix(stix)
            return chaser.pos
        }

        XCTAssertEqual(points, [Point(x: width / 2, y: height - 1), stix.head, stix.head])
        XCTAssertEqual(chaser.dir, .up)
    }

    func testASparxOffTheStixDoesNotStepAlongIt() {
        let stix = stixUp(width / 2, stixLength)
        let beside = normalSparx(Point(x: width / 2 + 1, y: height - 1), .left)
        var stepped = beside

        stepped.stepAlongStix(stix)

        XCTAssertEqual(stepped, beside)
    }

    func testTwoLevelSparxAreThePair() {
        let board = Board(width: width, height: height)

        XCTAssertEqual(Sparx.spawnLevel(board, 2), Sparx.spawnPair(board))
    }

    func testLevelSparxComeInPairsSpreadAlongTheTopEdge() {
        let board = Board(width: levelWidth, height: height)

        let spawned = Sparx.spawnLevel(board, levelSparx)

        let spots = spawned.map(Heading.init)
        let points = levelSparxX.map { Point(x: $0, y: 0) }
        let (first, second, third) = (points[0], points[1], points[2])
        XCTAssertEqual(spots, [
            Heading(first, .left),
            Heading(first, .right),
            Heading(second, .left),
            Heading(second, .right),
            Heading(third, .left),
        ])
        XCTAssert(spawned.allSatisfy { $0.kind == .normal })
    }

    func testLevelSparxSpawnOnTheBorderNearestTheirSpot() throws {
        let x = levelSparxX[0]
        var board = Board(width: levelWidth, height: height)
        board.setCell(x: x - 1, y: 0, to: claimed)
        board.setCell(x: x, y: 0, to: claimed)

        let spawned = Sparx.spawnLevel(board, levelSparx)

        let nearest = try XCTUnwrap(nearestBorderPoint(board, Point(x: x, y: 0)))
        XCTAssertNotEqual(nearest, Point(x: x, y: 0))
        XCTAssertEqual(spawned[0].pos, nearest)
        XCTAssert(spawned.allSatisfy { board.isBorder($0.pos) })
    }

    func testNoTopSparxSpawnNone() {
        XCTAssert(Sparx.spawnAtTop(Board(width: width, height: height), 0).isEmpty)
    }

    func testNoLevelSparxSpawnNone() {
        XCTAssert(Sparx.spawnLevel(Board(width: width, height: height), 0).isEmpty)
    }
}

/// The negative counts `Sparx.spawnAtTop` and `Sparx.spawnLevel` trap on, where Rust's `usize`
/// rules them out, as exit tests (TrapExpectation.swift).
struct SparxTrapTests {
    @Test func aNegativeTopCountTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = Sparx.spawnAtTop(Board(width: width, height: height), -1)
        }
        expectMessage(result, "negative Sparx count -1")
    }

    @Test func aNegativeLevelCountTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = Sparx.spawnLevel(Board(width: width, height: height), -1)
        }
        expectMessage(result, "negative Sparx count -1")
    }
}
