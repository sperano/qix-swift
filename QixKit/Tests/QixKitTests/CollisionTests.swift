import XCTest
@testable import QixKit

/// How far outside the marker's square the near misses pass.
private let missGap: Float = 0.1

/// The top speed at the end of the difficulty ramp, in playfield units per tick: one tick of it
/// moves a Qix a whole cell.
private let topSpeed: Float = 1.0

/// Where the vertical Qix of the sweep tests runs: between the rows of `upThenRight`'s vertical
/// leg, clear of its horizontal one.
private let sweepTop: Float = 6.0
private let sweepBottom: Float = 9.0

/// Where `testAQixCrossingTheStixWithinATickHitsIt` starts its Qix: closer to `upThenRight`'s
/// vertical leg, at `x = 2`, than the slowest Qix moves in a tick.
private let crossingStartX: Float = 1.75

/// The free board that Qix tick on.
private let sweepBoard: UInt16 = 12

/// Seed of the Qix that tick.
private let seed: UInt64 = 1_195

/// The vertical segment at `x` between `sweepTop` and `sweepBottom`.
private func verticalAt(_ x: Float) -> (Vec2, Vec2) {
    (Vec2(x: x, y: sweepTop), Vec2(x: x, y: sweepBottom))
}

/// A still Qix on the segment from `start` to `end`.
private func qix(_ start: (Float, Float), _ end: (Float, Float)) -> Qix {
    Qix(a: Vec2(x: start.0, y: start.1), b: Vec2(x: end.0, y: end.1), vel: Vec2(), spin: 0)
}

/// A stix up from `(2, 10)` to `(2, 5)`, then right to `(8, 5)`.
private func upThenRight() -> Stix {
    var stix = Stix(start: Point(x: 2, y: 10))
    stix.push(Point(x: 2, y: 5), .fast)
    stix.push(Point(x: 8, y: 5), .fast)
    return stix
}

final class CollisionTests: XCTestCase {
    func testAQixCrossingAHorizontalStixHitsIt() {
        XCTAssert(qixHitsStix(qix((5.0, 3.0), (5.0, 7.0)), upThenRight()))
    }

    func testAQixCrossingAVerticalStixHitsIt() {
        XCTAssert(qixHitsStix(qix((1.0, 8.0), (3.5, 7.5)), upThenRight()))
    }

    func testAQixEndingOnTheStixHitsIt() {
        XCTAssert(qixHitsStix(qix((5.0, 2.0), (5.0, 5.0)), upThenRight()))
    }

    func testAQixPassingBesideTheStixMissesIt() {
        let stix = upThenRight()
        XCTAssertFalse(qixHitsStix(qix((3.0, 4.5), (7.0, 4.5)), stix))
        XCTAssertFalse(qixHitsStix(qix((3.0, 6.0), (3.0, 9.0)), stix))
        XCTAssertFalse(qixHitsStix(qix((9.0, 3.0), (9.0, 7.0)), stix))
    }

    func testAQixThroughTheMarkerSquareHitsTheMarker() {
        let marker = Point(x: 4, y: 4)
        XCTAssert(qixHitsMarker(qix((3.0, 4.2), (5.0, 4.2)), marker))
        XCTAssert(qixHitsMarker(qix((4.4, 2.0), (4.4, 6.0)), marker))
    }

    func testAQixEnteringTheMarkerSquareThroughOneSideHitsTheMarker() {
        let marker = Point(x: 4, y: 4)
        let throughLeft = qix((3.0, 4.0), (3.8, 4.0))
        let throughRight = qix((5.5, 4.0), (4.2, 4.0))
        let throughTop = qix((4.0, 2.5), (4.0, 3.8))
        let throughBottom = qix((4.0, 5.5), (4.0, 4.2))
        for entering in [throughLeft, throughRight, throughTop, throughBottom] {
            XCTAssert(qixHitsMarker(entering, marker), "\(entering)")
        }
    }

    func testAQixInsideTheMarkerSquareHitsTheMarker() {
        XCTAssert(qixHitsMarker(qix((3.9, 4.0), (4.1, 4.0)), Point(x: 4, y: 4)))
    }

    func testAQixJustOutsideTheMarkerSquareMissesTheMarker() {
        let marker = Point(x: 4, y: 4)
        let near = 4.0 + Tuning.markerHitHalfSize + missGap
        let far = 4.0 - Tuning.markerHitHalfSize - missGap
        XCTAssertFalse(qixHitsMarker(qix((near, 2.0), (near, 6.0)), marker))
        XCTAssertFalse(qixHitsMarker(qix((2.0, far), (6.0, far)), marker))
    }

    func testASegmentCrossingTheStixWithinATickHitsIt() {
        let stix = upThenRight()
        let (before, after) = (
            verticalAt(2.0 - topSpeed / 2.0),
            verticalAt(2.0 + topSpeed / 2.0)
        )
        XCTAssertFalse(sweepHitsStix(before, before, stix), "starts on the stix")
        XCTAssertFalse(sweepHitsStix(after, after, stix), "ends on the stix")

        XCTAssert(sweepHitsStix(before, after, stix))
        XCTAssert(sweepHitsStix(after, before, stix))
    }

    func testAStixInsideTheSweptAreaIsHit() {
        var stix = Stix(start: Point(x: 2, y: 7))
        stix.push(Point(x: 2, y: 8), .fast)

        XCTAssert(sweepHitsStix(verticalAt(1.5), verticalAt(2.5), stix))
    }

    func testASegmentTurningPastItselfAcrossTheStixHitsIt() {
        var stix = Stix(start: Point(x: 3, y: 7))
        stix.push(Point(x: 3, y: 8), .fast)
        let before = (Vec2(x: 0.0, y: 9.5), Vec2(x: 4.0, y: 5.5))
        let after = (Vec2(x: 0.0, y: 5.5), Vec2(x: 4.0, y: 9.5))
        XCTAssertFalse(sweepHitsStix(before, before, stix), "starts on the stix")
        XCTAssertFalse(sweepHitsStix(after, after, stix), "ends on the stix")

        XCTAssert(sweepHitsStix(before, after, stix))
    }

    func testASegmentMovingBesideTheStixMissesIt() {
        let stix = upThenRight()

        XCTAssertFalse(sweepHitsStix(verticalAt(0.5), verticalAt(1.5), stix))
        XCTAssertFalse(sweepHitsStix(verticalAt(3.0), verticalAt(4.0), stix))
    }

    func testAQixCrossingTheStixWithinATickHitsIt() {
        let (start, end) = verticalAt(crossingStartX)
        var qix = Qix(a: start, b: end, vel: Vec2(x: Tuning.qixSpeed.upperBound, y: 0), spin: 0)
        let stix = upThenRight()
        XCTAssertFalse(qixHitsStix(qix, stix), "starts on the stix")
        var rng = Rng(seed: seed)

        qix.tick(Board(width: sweepBoard, height: sweepBoard), &rng)

        XCTAssert(qix.a.x > 2.0 && qix.b.x > 2.0, "\(qix) did not cross")
        XCTAssert(qixHitsStix(qix, stix))
    }

    func testAQixThatCrossedTheStixATickAgoDoesNotTouchIt() {
        let (start, end) = verticalAt(crossingStartX)
        var qix = Qix(a: start, b: end, vel: Vec2(x: Tuning.qixSpeed.upperBound, y: 0), spin: 0)
        let stix = upThenRight()
        XCTAssertFalse(qixTouchesStix(qix, stix), "starts on the stix")
        var rng = Rng(seed: seed)

        qix.tick(Board(width: sweepBoard, height: sweepBoard), &rng)

        XCTAssert(qixHitsStix(qix, stix), "\(qix) did not cross")
        XCTAssertFalse(qixTouchesStix(qix, stix))
    }

    func testAQixOnTheStixTouchesIt() {
        let stix = upThenRight()
        XCTAssert(qixTouchesStix(qix((5.0, 3.0), (5.0, 7.0)), stix))
        XCTAssert(qixTouchesStix(qix((5.0, 2.0), (5.0, 5.0)), stix))
        XCTAssertFalse(qixTouchesStix(qix((3.0, 6.0), (3.0, 9.0)), stix))
    }

    func testAnyOfTheQixHitsThePlayer() {
        let stix = upThenRight()
        let marker = Point(x: 8, y: 5)
        let far = qix((10.0, 10.0), (11.0, 10.0))
        let onStix = qix((5.0, 3.0), (5.0, 7.0))
        let onMarker = qix((8.2, 3.0), (8.2, 4.8))
        XCTAssertFalse(qixHitsStix(onMarker, stix), "touches the stix")

        XCTAssertFalse(qixHitsPlayer([far], stix, marker))
        for hit in [onStix, onMarker] {
            let (first, second) = ([far, hit], [hit, far])
            XCTAssert(qixHitsPlayer(first, stix, marker))
            XCTAssert(qixHitsPlayer(second, stix, marker))
        }
    }
}
