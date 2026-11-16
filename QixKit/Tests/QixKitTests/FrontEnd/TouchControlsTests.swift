import XCTest
@testable import QixKit

/// Where the stick's thumb lands in the tests, in points.
private let stickCentre = Vec2(x: 60, y: 200)

/// Where the Slow button's thumb lands, in points.
private let slowPoint = Vec2(x: 800, y: 200)

/// A drag well past the dead zone, in points.
private let far = 3 * FloatingStick.deadZone

/// A drag to the far side of the screen, well off the stick's zone, in points.
private let offZone: Float = 700

/// Where the board of the tests is on the screen: its top-left corner, and the points a cell
/// takes.
private let board = BoardFrame(origin: Vec2(x: 100, y: 50), pointsPerCell: 2)

/// A finger on the board, and where it aims: `BoardFrame.fingerLift` (20 cells) above it.
private let onBoard = Vec2(x: 120, y: 130)
private let onBoardAim = Vec2(x: 10, y: 20)

/// The touches of the tests.
private let thumb = 1
private let otherThumb = 2
private let finger = 3

/// The point `x` right of and `y` below `stickCentre`.
private func stick(_ x: Float, _ y: Float) -> Vec2 {
    stickCentre + Vec2(x: x, y: y)
}

final class TouchControlsTests: XCTestCase {
    private var touches = TouchControls<Int>()

    override func setUp() {
        super.setUp()
        touches = TouchControls()
    }

    /// The stick touched by `thumb` and dragged left.
    private func steerLeft() {
        touches.began(thumb, on: .stick, at: stickCentre)
        touches.moved(thumb, to: stick(-far, 0))
    }

    func testNothingTouchedHoldsNothing() {
        XCTAssertEqual(touches.held, [])
        XCTAssertFalse(touches.slowHeld)
        XCTAssertFalse(touches.stick.isTouched)
    }

    func testTheStickTouchedButNotDraggedHoldsNothing() {
        touches.began(thumb, on: .stick, at: stickCentre)

        XCTAssertTrue(touches.stick.isTouched)
        XCTAssertEqual(touches.stick.centre, stickCentre)
        XCTAssertEqual(touches.held, [])
    }

    func testAHeldDirectionDrawsFast() {
        steerLeft()

        XCTAssertEqual(touches.held, [.left, .fast])
    }

    func testTheSlowButtonHeldWithADirectionDrawsSlowInsteadOfFast() {
        steerLeft()
        touches.began(finger, on: .slow, at: slowPoint)

        XCTAssertTrue(touches.slowHeld)
        XCTAssertEqual(touches.held, [.left, .slow])
        var controls = Controls()
        controls.setTouch(touches.held)
        XCTAssertEqual(controls.sample().drawKind, .slow)
    }

    func testTheSlowButtonAloneHoldsSlow() {
        touches.began(finger, on: .slow, at: slowPoint)

        XCTAssertEqual(touches.held, [.slow])
    }

    func testLiftingTheSlowButtonGoesBackToFast() {
        steerLeft()
        touches.began(finger, on: .slow, at: slowPoint)

        touches.ended(finger)

        XCTAssertEqual(touches.held, [.left, .fast])
    }

    func testLiftingTheStickReleasesTheDirectionButNotTheSlowButton() {
        steerLeft()
        touches.began(finger, on: .slow, at: slowPoint)

        touches.ended(thumb)

        XCTAssertEqual(touches.held, [.slow])
        XCTAssertFalse(touches.stick.isTouched)
    }

    func testTheStickFollowsItsTouchOffItsZone() {
        steerLeft()

        touches.moved(thumb, to: stick(offZone, 0))

        XCTAssertEqual(touches.held, [.right, .fast])
        XCTAssertEqual(touches.stick.thumb, stick(offZone, 0))
    }

    func testASecondTouchOnTheStickHoldsNothing() {
        steerLeft()
        touches.began(otherThumb, on: .stick, at: stick(far, far))

        touches.moved(otherThumb, to: stick(far, -far))
        XCTAssertEqual(touches.stick.centre, stickCentre)
        XCTAssertEqual(touches.held, [.left, .fast])

        touches.ended(otherThumb)
        XCTAssertEqual(touches.held, [.left, .fast])
    }

    func testATouchOnTheSlowButtonDoesNotSteer() {
        touches.began(finger, on: .slow, at: slowPoint)

        touches.moved(finger, to: slowPoint + Vec2(x: -far, y: 0))

        XCTAssertFalse(touches.stick.isTouched)
        XCTAssertEqual(touches.held, [.slow])
    }

    func testTheSlowButtonStaysHeldUntilItsLastTouchLifts() {
        touches.began(finger, on: .slow, at: slowPoint)
        touches.began(otherThumb, on: .slow, at: slowPoint)

        touches.ended(finger)
        XCTAssertTrue(touches.slowHeld)
        touches.ended(otherThumb)
        XCTAssertFalse(touches.slowHeld)
    }

    func testAMoveOfAnEndedTouchDoesNothing() {
        steerLeft()
        touches.ended(thumb)

        touches.moved(thumb, to: stick(far, 0))

        XCTAssertEqual(touches, TouchControls())
    }

    func testTheStickReleasedTakesTheNextTouchWithItsOwnCentre() {
        steerLeft()
        touches.ended(thumb)
        let next = stick(far, far)

        touches.began(otherThumb, on: .stick, at: next)
        touches.moved(otherThumb, to: next + Vec2(x: 0, y: -far))

        XCTAssertEqual(touches.stick.centre, next)
        XCTAssertEqual(touches.held, [.up, .fast])
    }

    /// A thumb resting on the stick while the marker is on the border wanders inside the dead
    /// zone: the marker neither leaves the border nor moves along it. The same thumb dragged past
    /// the dead zone then starts a fast stix off the border, with no button.
    func testAThumbJitteringInsideTheDeadZoneOnTheBorderNeverLeavesIt() {
        let qix = Qix(a: Vec2(x: 79, y: 40), b: Vec2(x: 81, y: 40), vel: Vec2(), spin: 0)
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        var game = Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: 0))
        let start = game.marker.pos
        var controls = Controls()
        let inside = FloatingStick.deadZone - 1
        let wander = [stick(0, -inside), stick(inside, 0), stick(-inside / 2, -inside / 2), stick(-inside, 0)]
        touches.began(thumb, on: .stick, at: stickCentre)

        for point in Array(repeating: wander, count: Int(Tuning.slowStepTicks) * 4).joined() {
            touches.moved(thumb, to: point)
            controls.setTouch(touches.held)
            game.tick(controls.sample())
            XCTAssertNil(game.stix, "\(point)")
            XCTAssertEqual(game.marker.pos, start, "\(point)")
        }

        touches.moved(thumb, to: stick(0, -far))
        controls.setTouch(touches.held)
        for _ in 0 ..< Tuning.markerStepTicks {
            game.tick(controls.sample())
        }
        XCTAssertEqual(game.stix?.kinds, [DrawKind.fast])
        XCTAssertEqual(game.marker.pos, Point(x: start.x, y: start.y - 1))
    }

    func testAFingerOnTheBoardInPlayAimsAboveIt() {
        touches.began(finger, on: .board(board), at: onBoard)

        XCTAssertEqual(touches.aim, onBoardAim)
        XCTAssertEqual(touches.held, [])
    }

    func testTheAimFollowsItsFingerOffTheBoard() {
        touches.began(finger, on: .board(board), at: onBoard)

        touches.moved(finger, to: Vec2(x: 40, y: 10))

        XCTAssertEqual(touches.aim, Vec2(x: -30, y: -40))
    }

    func testLiftingTheBoardsFingerAimsAtNothingAndIsNoTap() {
        touches.began(finger, on: .board(board), at: onBoard)

        XCTAssertFalse(touches.ended(finger))
        XCTAssertNil(touches.aim)
        XCTAssertEqual(touches, TouchControls())
    }

    func testASecondFingerOnTheBoardAimsAtNothing() {
        touches.began(finger, on: .board(board), at: onBoard)
        touches.began(otherThumb, on: .board(board), at: onBoard + Vec2(x: far, y: far))

        touches.moved(otherThumb, to: Vec2())
        XCTAssertEqual(touches.aim, onBoardAim)

        XCTAssertFalse(touches.ended(otherThumb))
        XCTAssertEqual(touches.aim, onBoardAim)
    }

    func testAFingerOnTheBoardOutOfPlayIsATapNotAnAim() {
        touches.began(finger, on: .board(board), at: onBoard, inPlay: false)
        touches.moved(finger, to: Vec2())
        XCTAssertNil(touches.aim)

        XCTAssertTrue(touches.ended(finger))
        XCTAssertFalse(touches.ended(finger), "a tap ends once")
        XCTAssertEqual(touches, TouchControls())
    }

    func testACancelledFingerOnTheBoardOutOfPlayIsNoTap() {
        touches.began(finger, on: .board(board), at: onBoard, inPlay: false)

        touches.cancelled(finger)

        XCTAssertFalse(touches.ended(finger), "the cancel ended the tap")
        XCTAssertEqual(touches, TouchControls())
    }

    func testCancelledTouchesLetGoOfTheirControls() {
        steerLeft()
        touches.began(finger, on: .board(board), at: onBoard)
        touches.began(otherThumb, on: .slow, at: slowPoint)

        touches.cancelled(thumb)
        touches.cancelled(finger)
        touches.cancelled(otherThumb)

        XCTAssertEqual(touches, TouchControls())
    }

    func testTouchesOffTheBoardAreNoTaps() {
        steerLeft()
        touches.began(finger, on: .slow, at: slowPoint)

        XCTAssertFalse(touches.ended(thumb))
        XCTAssertFalse(touches.ended(finger))
    }

    /// The board's finger and the Slow button draw together; the stick is not touched.
    func testTheBoardsFingerAndTheSlowButtonHoldTogether() {
        touches.began(finger, on: .board(board), at: onBoard)
        touches.began(thumb, on: .slow, at: slowPoint)

        XCTAssertEqual(touches.aim, onBoardAim)
        XCTAssertEqual(touches.held, [.slow])
        XCTAssertFalse(touches.stick.isTouched)
    }

    func testABoardFrameAimsLiftedAboveTheFingerInCells() {
        let frame = BoardFrame(origin: Vec2(x: 10, y: 20), pointsPerCell: 4)

        XCTAssertEqual(frame.aim(at: Vec2(x: 10, y: 20 + BoardFrame.fingerLift)), Vec2())
        XCTAssertEqual(frame.aim(at: Vec2(x: 30, y: 20)), Vec2(x: 5, y: -BoardFrame.fingerLift / 4))
    }
}
