import XCTest
@testable import QixKit

/// Where the thumb lands in the tests, in points.
private let centre = Vec2(x: 100, y: 200)

/// A drag well past the dead zone, in points.
private let far = 3 * FloatingStick.deadZone

/// How far a resting or sliding thumb wanders, in points.
private let jitter: Float = 3

/// Just under the dead zone, in points.
private let inside = FloatingStick.deadZone - 0.5

/// The directions a stick touched at `centre` holds as the thumb moves through `offsets` from it.
private func dirs(_ offsets: [Vec2]) -> [Dir?] {
    var stick = FloatingStick()
    stick.touchDown(at: centre)
    return offsets.map { offset in
        stick.move(to: centre + offset)
        return stick.dir
    }
}

final class FloatingStickTests: XCTestCase {
    func testAStickNotTouchedHoldsNothing() {
        let stick = FloatingStick()

        XCTAssertFalse(stick.isTouched)
        XCTAssertNil(stick.centre)
        XCTAssertNil(stick.thumb)
        XCTAssertNil(stick.dir)
    }

    func testTheThumbLandingIsTheCentreAndHoldsNoDirection() {
        var stick = FloatingStick()
        stick.touchDown(at: centre)

        XCTAssertTrue(stick.isTouched)
        XCTAssertEqual(stick.centre, centre)
        XCTAssertEqual(stick.thumb, centre)
        XCTAssertNil(stick.dir)
    }

    func testTheDominantAxisOfTheDragHoldsTheDirectionWithYDown() {
        XCTAssertEqual(dirs([Vec2(x: far, y: jitter)]), [.right])
        XCTAssertEqual(dirs([Vec2(x: -far, y: -jitter)]), [.left])
        XCTAssertEqual(dirs([Vec2(x: jitter, y: far)]), [.down])
        XCTAssertEqual(dirs([Vec2(x: -jitter, y: -far)]), [.up])
    }

    func testTheThumbFollowsTheTouch() {
        var stick = FloatingStick()
        stick.touchDown(at: centre)
        stick.move(to: centre + Vec2(x: far, y: 0))

        XCTAssertEqual(stick.thumb, centre + Vec2(x: far, y: 0))
        XCTAssertEqual(stick.centre, centre)
    }

    func testADragInsideTheDeadZoneHoldsNoDirection() {
        let offsets = [Vec2(x: inside, y: 0), Vec2(x: 0, y: -inside), Vec2(x: -jitter, y: jitter)]

        XCTAssertEqual(dirs(offsets), [nil, nil, nil])
    }

    /// The dead zone is round: a drag past it holds a direction though neither axis reaches it.
    func testTheDeadZoneIsTheDistanceFromTheCentre() {
        let offset = Vec2(x: inside, y: inside - jitter)

        XCTAssertGreaterThan(offset.length, FloatingStick.deadZone)
        XCTAssertEqual(dirs([offset]), [.right])
    }

    func testADragReachingTheDeadZoneHoldsTheDirection() {
        XCTAssertEqual(dirs([Vec2(x: FloatingStick.deadZone, y: 0)]), [.right])
    }

    func testTheThumbBackInsideTheDeadZoneHoldsNoDirection() {
        XCTAssertEqual(dirs([Vec2(x: far, y: 0), Vec2(x: inside, y: 0)]), [.right, nil])
    }

    func testAnExactDiagonalWithNothingHeldHoldsNoDirection() {
        XCTAssertEqual(dirs([Vec2(x: far, y: far)]), [nil])
    }

    /// A thumb sliding down a diagonal, leading on one axis then the other, holds the direction it
    /// first held.
    func testAThumbOnADiagonalDoesNotFlicker() {
        let path = [
            Vec2(x: far + jitter, y: far), Vec2(x: far, y: far + jitter), Vec2(x: far - jitter, y: far + jitter),
            Vec2(x: 2 * far, y: 2 * far + jitter), Vec2(x: far + jitter, y: far - jitter), Vec2(x: far, y: far),
        ]

        XCTAssertEqual(dirs(path), Array(repeating: .right, count: path.count))
        let mirrored = path.map { Vec2(x: $0.y, y: $0.x) }
        XCTAssertEqual(dirs(mirrored), Array(repeating: .down, count: path.count))
    }

    func testTheOtherAxisLeadingByTheRatioKeepsTheHeldAxis() {
        let edge = Vec2(x: far, y: far * FloatingStick.axisSwitchRatio)

        XCTAssertEqual(dirs([Vec2(x: far, y: 0), edge]), [.right, .right])
        XCTAssertEqual(dirs([Vec2(x: 0, y: -far), Vec2(x: -edge.y, y: -edge.x)]), [.up, .up])
    }

    func testTheOtherAxisLeadingPastTheRatioSwitchesAxis() {
        let past = Vec2(x: far, y: far * FloatingStick.axisSwitchRatio + jitter)

        XCTAssertEqual(dirs([Vec2(x: far, y: 0), past]), [.right, .down])
        XCTAssertEqual(dirs([Vec2(x: 0, y: -far), Vec2(x: -past.y, y: -past.x)]), [.up, .left])
    }

    func testADragStraightAlongTheOtherAxisSwitchesToIt() {
        XCTAssertEqual(dirs([Vec2(x: far, y: 0), Vec2(x: 0, y: -far)]), [.right, .up])
        XCTAssertEqual(dirs([Vec2(x: 0, y: far), Vec2(x: -far, y: 0)]), [.down, .left])
    }

    func testADragAcrossTheCentreReversesTheDirection() {
        XCTAssertEqual(dirs([Vec2(x: far, y: 0), Vec2(x: 0, y: 0), Vec2(x: -far, y: 0)]), [.right, nil, .left])
        XCTAssertEqual(dirs([Vec2(x: 0, y: far), Vec2(x: 0, y: -far)]), [.down, .up])
    }

    func testLiftingTheThumbReleasesTheStick() {
        var stick = FloatingStick()
        stick.touchDown(at: centre)
        stick.move(to: centre + Vec2(x: far, y: 0))

        stick.lift()

        XCTAssertEqual(stick, FloatingStick())
    }

    func testAMoveWithoutTouchHoldsNothing() {
        var stick = FloatingStick()
        stick.move(to: centre + Vec2(x: far, y: 0))

        XCTAssertEqual(stick, FloatingStick())
    }

    func testTouchingDownAgainMovesTheCentreAndDropsTheDirection() {
        var stick = FloatingStick()
        stick.touchDown(at: centre)
        stick.move(to: centre + Vec2(x: far, y: 0))
        let next = centre + Vec2(x: far, y: far)

        stick.touchDown(at: next)

        XCTAssertEqual(stick.centre, next)
        XCTAssertNil(stick.dir)
    }
}
