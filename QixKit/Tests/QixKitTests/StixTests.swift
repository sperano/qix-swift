import Testing
import XCTest
@testable import QixKit

/// Dimensions of the board the tests draw on.
private let width: UInt16 = 6
private let height: UInt16 = 5

/// Where the stixes in these tests leave the border: the bottom edge.
private let start = Point(x: 3, y: height)

private func board() -> Board {
    Board(width: width, height: height)
}

/// A stix from `start` along `path`, every step drawn with `kind`.
private func drawnWith(_ start: Point, _ path: [Dir], _ kind: DrawKind) -> Stix {
    var stix = Stix(start: start)
    for dir in path {
        stix.push(dir.step(stix.head)!, kind)
    }
    return stix
}

/// A fast stix from `start` along `path`.
private func drawn(_ path: [Dir]) -> Stix {
    drawnWith(start, path, .fast)
}

/// The marker drawing `stix`, at its head.
private func markerOn(_ stix: Stix) -> Marker {
    Marker(pos: stix.head, state: .drawing)
}

private func step(_ stix: Stix, _ board: Board, _ dir: Dir) -> Point? {
    legalStep(markerOn(stix), stix, board, dir)
}

final class StixTests: XCTestCase {
    func testANewStixIsItsStart() {
        let stix = Stix(start: start)

        XCTAssertEqual(stix.start, start)
        XCTAssertEqual(stix.head, start)
        XCTAssertEqual(stix.points, [start])
        XCTAssert(stix.kinds.isEmpty)
        XCTAssert(stix.containsPoint(start))
    }

    func testStraightStepsOfOneKindLengthenOneSegment() {
        let stix = drawn([.up, .up, .up])

        XCTAssertEqual(stix.points, [start, Point(x: 3, y: height - 3)])
        XCTAssertEqual(stix.kinds, [.fast])
    }

    func testATurnStartsASegment() {
        let stix = drawn([.up, .up, .left])

        let corner = Point(x: 3, y: height - 2)
        XCTAssertEqual(stix.points, [start, corner, Point(x: 2, y: height - 2)])
        XCTAssertEqual(stix.kinds, [.fast, .fast])
        XCTAssertEqual(stix.head, Point(x: 2, y: height - 2))
    }

    func testAChangeOfButtonStartsASegment() {
        var stix = drawn([.up])

        stix.push(Point(x: 3, y: height - 2), .slow)

        XCTAssertEqual(stix.points, [start, Point(x: 3, y: height - 1), Point(x: 3, y: height - 2)])
        XCTAssertEqual(stix.kinds, [.fast, .slow])
    }

    func testContainsEveryPointAlongItsSegments() {
        let stix = drawn([.up, .up, .left])

        for point in [start, Point(x: 3, y: height - 1), Point(x: 2, y: height - 2)] {
            XCTAssert(stix.containsPoint(point), "\(point)")
        }
        XCTAssertFalse(stix.containsPoint(Point(x: 2, y: height - 1)))
        XCTAssertFalse(stix.containsPoint(Point(x: 3, y: height - 3)))
    }

    func testContainsTheUnitEdgesItCoversEitherWayRound() {
        let stix = drawn([.up, .up, .left])
        let (lower, upper) = (Point(x: 3, y: height - 1), Point(x: 3, y: height - 2))
        let left = Point(x: 2, y: height - 2)

        XCTAssert(stix.containsSegment(lower, upper))
        XCTAssert(stix.containsSegment(upper, lower))
        XCTAssert(stix.containsSegment(upper, left))
        XCTAssertFalse(stix.containsSegment(lower, Point(x: 2, y: height - 1)))
        XCTAssertFalse(stix.containsSegment(left, Point(x: 2, y: height - 1)))
        XCTAssertFalse(stix.containsSegment(lower, lower))
    }

    func testAStixDrawnSlowThroughoutClaimsSlow() {
        let stix = drawnWith(start, [.up, .left], .slow)

        XCTAssertEqual(stix.claimKind(), .slow)
    }

    func testASingleFastSegmentMakesTheClaimFast() {
        var stix = drawnWith(start, [.up, .up], .slow)
        stix.push(Point(x: 2, y: height - 2), .fast)
        stix.push(Point(x: 1, y: height - 2), .slow)

        XCTAssertEqual(stix.claimKind(), .fast)
    }

    func testAStixWithoutSegmentsClaimsFast() {
        XCTAssertEqual(Stix(start: start).claimKind(), .fast)
    }

    func testTheFirstStepLeavesTheBorderIntoFreeSpaceOnly() {
        let stix = Stix(start: start)

        XCTAssertEqual(legalMoves(markerOn(stix), stix, board()), [.up])
        XCTAssertEqual(step(stix, board(), .up), Point(x: 3, y: height - 1))
    }

    func testAStixCannotStartIntoAClaimedArea() {
        var board = board()
        board.setCell(x: 2, y: height - 2, to: .claimed(.fast))
        board.setCell(x: 2, y: height - 1, to: .claimed(.fast))
        let stix = Stix(start: Point(x: 3, y: height - 1))

        XCTAssertNil(step(stix, board, .left))
        XCTAssertEqual(legalMoves(markerOn(stix), stix, board), [.right])
    }

    func testCrossingTheStixIsRefused() {
        let stix = drawn([.up, .up, .up, .left, .down])

        XCTAssert(stix.containsPoint(Point(x: 3, y: height - 2)))
        XCTAssertNil(step(stix, board(), .right))
    }

    func testRetracingTheLastSegmentAfterATurnIsRefused() {
        let stix = drawn([.up, .up, .left])

        XCTAssertNil(step(stix, board(), .right))
    }

    func testAUTurnIsRefused() {
        let stix = drawn([.up, .up])

        XCTAssertNil(step(stix, board(), .down))
        XCTAssertEqual(legalMoves(markerOn(stix), stix, board()), [.up, .left, .right])
    }

    func testReturningToTheStartOverTheStixIsRefused() {
        let stix = drawn([.up])

        XCTAssertNil(step(stix, board(), .down))
    }

    func testClosingOnTheBorderIsAccepted() {
        let stix = drawn([.up, .up, .up, .up])
        let top = Point(x: 3, y: 0)

        XCTAssertEqual(step(stix, board(), .up), top)
        XCTAssert(board().isBorder(top))
    }

    func testClosingOnAClaimedAreaIsAccepted() {
        var board = board()
        board.setCell(x: 0, y: 0, to: .claimed(.fast))
        let stix = drawnWith(Point(x: 1, y: height), [.up, .up, .up], .fast)

        XCTAssertEqual(step(stix, board, .up), Point(x: 1, y: 1))
    }

    func testClosingOnTheStartOverANewEdgeIsAccepted() {
        var board = board()
        board.setCell(x: 0, y: 0, to: .claimed(.fast))
        let corner = Point(x: 1, y: 1)
        let stix = drawnWith(corner, [.right, .down, .left], .fast)

        XCTAssertEqual(step(stix, board, .up), corner)
    }

    func testADeadEndHasNoLegalMove() {
        let stix = drawn([.up, .up, .up, .left, .left, .down, .down, .right, .up])

        XCTAssertEqual(stix.head, Point(x: 2, y: height - 2))
        XCTAssert(legalMoves(markerOn(stix), stix, board()).isEmpty)
    }

    func testTowardsHeadFollowsTheSegmentsRoundTheirCorners() {
        let stix = drawn([.up, .up, .right, .up])
        let corner = Point(x: start.x, y: height - 2)

        XCTAssertEqual(stix.towardsHead(start), .up)
        XCTAssertEqual(stix.towardsHead(Point(x: start.x, y: height - 1)), .up)
        XCTAssertEqual(stix.towardsHead(corner), .right)
        XCTAssertEqual(stix.towardsHead(Point(x: start.x + 1, y: height - 2)), .up)
    }

    func testTowardsHeadIsNoneAtTheHeadAndOffTheStix() {
        let stix = drawn([.up, .up])

        XCTAssertNil(stix.towardsHead(stix.head))
        XCTAssertNil(stix.towardsHead(Point(x: start.x + 1, y: height - 1)))
    }

    /// A step off the coordinate range, which `legalStep` checks before the board.
    func testAStepPastTheCoordinateRangeIsRefused() {
        let corner = Point(x: 0, y: 0)
        let stix = Stix(start: corner)

        XCTAssertNil(step(stix, board(), .left))
        XCTAssertNil(step(stix, board(), .up))
    }
}

/// Rust's `#[should_panic]` test and debug assertion, as exit tests (TrapExpectation.swift).
struct StixTrapTests {
    @Test func aDiagonalStepTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            var stix = Stix(start: Point(x: 3, y: 5))
            stix.push(Point(x: 2, y: 4), .fast)
        }
        expectMessage(result, "is not straight")
    }

    /// Rust's `debug_assert_eq!` in `legal_step`: `swift test` builds for debugging, so the
    /// `assert` runs.
    @Test func aStepFromAMarkerOffTheHeadTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            let stix = Stix(start: Point(x: 3, y: 5))
            let marker = Marker(pos: Point(x: 2, y: 5), state: .drawing)
            _ = legalStep(marker, stix, Board(width: 6, height: 5), .up)
        }
        expectMessage(result, "the marker is not at the head")
    }
}
