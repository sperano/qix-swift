import XCTest
@testable import QixKit

/// The cells from `from` to `to`, each as `[x, y]`.
private func walk(_ from: (Float, Float), _ to: (Float, Float)) -> [[Int32]] {
    Segment.cells(Vec2(x: from.0, y: from.1), Vec2(x: to.0, y: to.1)).map { [$0.0, $0.1] }
}

final class SegmentTests: XCTestCase {
    func testASegmentInsideOneCellIsThatCell() {
        XCTAssertEqual(walk((2.2, 3.1), (2.8, 3.9)), [[2, 3]])
    }

    func testAPointIsItsCell() {
        XCTAssertEqual(walk((2.5, 3.5), (2.5, 3.5)), [[2, 3]])
    }

    func testAHorizontalSegmentCrossesItsRow() {
        XCTAssertEqual(walk((0.5, 1.5), (3.5, 1.5)), [[0, 1], [1, 1], [2, 1], [3, 1]])
    }

    func testAVerticalSegmentWalksUpwards() {
        XCTAssertEqual(walk((1.5, 2.5), (1.5, 0.5)), [[1, 2], [1, 1], [1, 0]])
    }

    func testAShallowSegmentStepsDownWhereItCrossesTheRow() {
        let cells = walk((0.5, 0.2), (3.5, 1.2))

        XCTAssertEqual(cells, [[0, 0], [1, 0], [2, 0], [2, 1], [3, 1]])
    }

    func testWalkingBackwardsVisitsTheSameCellsInReverse() {
        let (from, to): ((Float, Float), (Float, Float)) = ((0.3, 0.7), (5.9, 3.1))

        XCTAssertEqual(walk(from, to), walk(to, from).reversed())
    }

    func testEveryStepIsToASideNeighbourAndTheWalkEndsAtTheEndCell() {
        let cells = walk((10.1, 4.9), (-3.7, -2.2))

        for (before, after) in zip(cells, cells.dropFirst()) {
            let distance = abs(before[0] - after[0]) + abs(before[1] - after[1])
            XCTAssertEqual(distance, 1, "\(before) \(after)")
        }
        XCTAssertEqual(cells.first, [10, 4])
        XCTAssertEqual(cells.last, [-4, -3])
    }

    func testASegmentStartingOnABoundaryMovingBackLeavesAtOnce() {
        XCTAssertEqual(walk((2.0, 0.5), (1.5, 0.5)), [[2, 0], [1, 0]])
    }

    /// Rust's `as i32` saturates where Swift's conversion would trap.
    func testCoordinatesBeyondInt32SaturateAtItsBounds() {
        XCTAssertEqual(walk((1e10, -1e10), (1e10, -1e10)), [[.max, .min]])
    }

    /// Ends saturated at opposite bounds of `Int32`: the cells between them are counted in a
    /// wider type, where an `Int32` subtraction would trap.
    func testASegmentSpanningAllOfInt32StartsAtItsLowerBound() {
        let cells = Segment.cells(Vec2(x: -1e10, y: 0), Vec2(x: 1e10, y: 0)).prefix(2).map { [$0.0, $0.1] }

        XCTAssertEqual(cells, [[.min, 0], [.min + 1, 0]])
    }

    func testADiagonalThroughALatticePointEntersOneSideCell() {
        XCTAssertEqual(walk((0, 0), (2, 2)), [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]])
    }

    /// Rust's `as i32` reads NaN as zero where Swift's conversion would trap.
    func testANotANumberCoordinateIsCellZero() {
        XCTAssertEqual(walk((.nan, 0.5), (.nan, 0.5)), [[0, 0]])
    }
}
