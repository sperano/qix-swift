import XCTest
@testable import QixKit

private func v(_ x: Float, _ y: Float) -> Vec2 {
    Vec2(x: x, y: y)
}

/// A right triangle with its right angle at the origin.
private func rightTriangle() -> (Vec2, Vec2, Vec2) {
    (v(0, 0), v(4, 0), v(0, 4))
}

final class GeometryTests: XCTestCase {
    func testOppositePairsTheDirections() {
        XCTAssertEqual(Dir.up.opposite, .down)
        XCTAssertEqual(Dir.down.opposite, .up)
        XCTAssertEqual(Dir.left.opposite, .right)
        XCTAssertEqual(Dir.right.opposite, .left)
    }

    func testOppositeTwiceIsTheSameDirection() {
        for dir in Dir.all {
            XCTAssertEqual(dir.opposite.opposite, dir)
        }
    }

    func testStepMovesOneLatticeUnitWithYGrowingDown() {
        let point = Point(x: 5, y: 7)
        XCTAssertEqual(Dir.up.step(point), Point(x: 5, y: 6))
        XCTAssertEqual(Dir.down.step(point), Point(x: 5, y: 8))
        XCTAssertEqual(Dir.left.step(point), Point(x: 4, y: 7))
        XCTAssertEqual(Dir.right.step(point), Point(x: 6, y: 7))
    }

    func testSteppingBackReturnsToTheStart() {
        let point = Point(x: 3, y: 3)
        for dir in Dir.all {
            let next = dir.step(point).flatMap { dir.opposite.step($0) }
            XCTAssertEqual(next, point, "\(dir)")
        }
    }

    func testStepPastTheCoordinateRangeIsNone() {
        XCTAssertNil(Dir.up.step(Point(x: 4, y: 0)))
        XCTAssertNil(Dir.left.step(Point(x: 0, y: 4)))
        XCTAssertNil(Dir.down.step(Point(x: 4, y: .max)))
        XCTAssertNil(Dir.right.step(Point(x: .max, y: 4)))
    }

    func testBetweenPointsTheWayOfAStraightRun() {
        let from = Point(x: 3, y: 3)
        let runs: [(Point, Dir)] = [
            (Point(x: 3, y: 1), .up),
            (Point(x: 3, y: 4), .down),
            (Point(x: 0, y: 3), .left),
            (Point(x: 5, y: 3), .right),
        ]

        for (to, dir) in runs {
            XCTAssertEqual(Dir.between(from, to), dir, "\(to)")
        }
    }

    func testBetweenHasNoDirectionForTheSamePointOrADiagonal() {
        let from = Point(x: 3, y: 3)

        XCTAssertNil(Dir.between(from, from))
        XCTAssertNil(Dir.between(from, Point(x: 4, y: 4)))
    }

    func testCrossingSegmentsIntersect() {
        XCTAssert(segmentsIntersect(v(0, 0), v(2, 2), v(0, 2), v(2, 0)))
        XCTAssert(segmentsIntersect(v(1, 0), v(1, 4), v(0, 2), v(3, 2)))
    }

    func testSegmentsTouchingAtAnEndIntersect() {
        XCTAssert(segmentsIntersect(v(0, 0), v(1, 1), v(1, 1), v(2, 0)))
        XCTAssert(segmentsIntersect(v(1, 0), v(1, 2), v(0, 2), v(3, 2)))
    }

    /// Each end of either segment lying on the other, one case per end.
    func testASegmentWithAnyEndOnTheOtherIntersects() {
        XCTAssert(segmentsIntersect(v(1, 2), v(1, 4), v(0, 2), v(3, 2)))
        XCTAssert(segmentsIntersect(v(0, 2), v(3, 2), v(1, 2), v(1, 4)))
        XCTAssert(segmentsIntersect(v(0, 2), v(3, 2), v(1, 4), v(1, 2)))
    }

    func testOverlappingCollinearSegmentsIntersect() {
        XCTAssert(segmentsIntersect(v(0, 1), v(3, 1), v(2, 1), v(5, 1)))
    }

    func testParallelSegmentsDoNotIntersect() {
        XCTAssertFalse(segmentsIntersect(v(0, 0), v(3, 0), v(0, 1), v(3, 1)))
    }

    func testDisjointCollinearSegmentsDoNotIntersect() {
        XCTAssertFalse(segmentsIntersect(v(0, 1), v(1, 1), v(2, 1), v(3, 1)))
    }

    func testSegmentsWhoseLinesCrossElsewhereDoNotIntersect() {
        XCTAssertFalse(segmentsIntersect(v(0, 0), v(1, 1), v(3, 0), v(2, 1)))
        XCTAssertFalse(segmentsIntersect(v(1, 0), v(1, 1.5), v(0, 2), v(3, 2)))
    }

    func testIntersectingIsSymmetric() {
        let (start, end) = (v(0, 0), v(2, 2))
        let (otherStart, otherEnd) = (v(0, 2), v(2, 0))
        XCTAssert(segmentsIntersect(otherStart, otherEnd, start, end))
        XCTAssert(segmentsIntersect(end, start, otherEnd, otherStart))
    }

    func testAPointInsideATriangleIsInItEitherWayRound() {
        let triangle = rightTriangle()
        let (first, second, third) = triangle
        let point = v(1, 1)

        XCTAssert(inTriangle(point, triangle))
        XCTAssert(inTriangle(point, (first, third, second)))
    }

    func testAPointOnASideOrACornerIsInTheTriangle() {
        let triangle = rightTriangle()

        XCTAssert(inTriangle(v(2, 0), triangle))
        XCTAssert(inTriangle(v(2, 2), triangle))
        XCTAssert(inTriangle(v(0, 4), triangle))
    }

    func testAPointOutsideATriangleIsNotInIt() {
        let triangle = rightTriangle()

        XCTAssertFalse(inTriangle(v(3, 3), triangle))
        XCTAssertFalse(inTriangle(v(-0.1, 1), triangle))
    }

    func testATriangleWithNoAreaHoldsNoPoint() {
        let flat = (v(0, 0), v(2, 0), v(4, 0))

        XCTAssertFalse(inTriangle(v(1, 0), flat))
        XCTAssertFalse(inTriangle(v(6, 0), flat))
    }
}
