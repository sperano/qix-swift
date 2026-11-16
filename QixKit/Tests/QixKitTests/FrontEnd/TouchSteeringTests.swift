import XCTest
@testable import QixKit

/// The full board: the marker starts at `(80, 120)`, the middle of its bottom edge, and the Qix in
/// the top-left cell is too far to reach the stix of a test before it ends.
private let steeringWidth = Tuning.boardW
private let steeringHeight = Tuning.boardH

/// Ticks enough for the marker to go round the whole board's border twice.
private let longRun = 4 * UInt32(steeringWidth + steeringHeight) * Tuning.markerStepTicks

/// A game on a free full board, or on `board`, with a still Qix in the top-left cell and no Sparx.
private func steeringGame(_ board: Board = Board(width: steeringWidth, height: steeringHeight)) -> Game {
    Game(board: board, qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: gameSeed))
}

/// A full board with the cells from `xs` across and `ys` down claimed.
private func claimedBlock(_ xs: Range<UInt16>, _ ys: Range<UInt16>) -> Board {
    var board = Board(width: steeringWidth, height: steeringHeight)
    for y in ys {
        for x in xs {
            board.setCell(x: x, y: y, to: .claimed(.fast))
        }
    }
    return board
}

/// The aim at lattice point `(x, y)`.
private func aim(_ x: UInt16, _ y: UInt16) -> Vec2 {
    Vec2(Point(x: x, y: y))
}

/// The lattice point `(x, y)`.
private func point(_ x: UInt16, _ y: UInt16) -> Point {
    Point(x: x, y: y)
}

/// Ticks `game` with the direction `steering` holds and the fast-draw button, as drawing B does,
/// `ticks` times, or by default until `steering` holds no direction (`longRun` ticks at most), and
/// returns the marker's points after each step it took.
@discardableResult
private func follow(_ steering: inout TouchSteering, _ game: inout Game, _ ticks: UInt32? = nil) -> [Point] {
    var points: [Point] = []
    for _ in 0 ..< (ticks ?? longRun) {
        let dir = steering.dir(game)
        if ticks == nil, dir == nil {
            break
        }
        let from = game.marker.pos
        game.tick(InputState(dir: dir, fast: true))
        if game.marker.pos != from {
            points.append(game.marker.pos)
        }
    }
    return points
}

final class TouchSteeringTests: XCTestCase {
    private var steering = TouchSteering()
    private var game = steeringGame()

    override func setUp() {
        super.setUp()
        steering = TouchSteering()
        game = steeringGame()
    }

    /// The marker drawn straight up to `(80, 114)`.
    private func drawUp() {
        steering.steer(towards: aim(80, 114))
        follow(&steering, &game)
        XCTAssertEqual(game.stix?.head, point(80, 114))
    }

    func testNothingAimedAtHoldsNoDirection() {
        XCTAssertNil(steering.aim)
        XCTAssertNil(steering.target(on: game.board))
        XCTAssertNil(steering.dir(game))
    }

    func testAStraightRunDrawsToTheTargetAndStopsThere() {
        steering.steer(towards: aim(80, 114))

        let points = follow(&steering, &game)

        XCTAssertEqual(points, (114 ..< 120).reversed().map { point(80, $0) })
        XCTAssertEqual(game.marker.state, .drawing)
        XCTAssertEqual(game.stix?.points, [point(80, 120), point(80, 114)])
        XCTAssertNil(steering.dir(game))
    }

    /// Up first, as the target is further up than across, and up until level with it: a stateless
    /// choice would turn at the tie four steps up and draw a staircase.
    func testTheDominantAxisFirstThenTheOther() {
        steering.steer(towards: aim(84, 112))

        follow(&steering, &game)

        XCTAssertEqual(game.stix?.points, [point(80, 120), point(80, 112), point(84, 112)])
    }

    /// Left first, along the border, then up into free space.
    func testAHorizontalDominantAxisRunsAlongTheBorderFirst() {
        steering.steer(towards: aim(73, 117))

        follow(&steering, &game)

        XCTAssertEqual(game.stix?.points, [point(73, 120), point(73, 117)])
    }

    func testATieGoesAcrossFirst() {
        steering.steer(towards: aim(83, 117))

        XCTAssertEqual(steering.dir(game), .right)
        follow(&steering, &game)
        XCTAssertEqual(game.stix?.points, [point(83, 120), point(83, 117)])
    }

    /// Dragged across once the marker heads up, the target lies further across than up: the marker
    /// still goes up until level with it, then across.
    func testMovingTheAimKeepsTheAxisHeld() {
        steering.steer(towards: aim(80, 108))
        follow(&steering, &game, 2 * Tuning.markerStepTicks)
        XCTAssertEqual(game.marker.pos, point(80, 118))

        steering.steer(towards: aim(88, 114))
        follow(&steering, &game)

        XCTAssertEqual(game.stix?.points, [point(80, 120), point(80, 114), point(88, 114)])
    }

    /// Reached, the target holds no direction, and the fuse lights as it does under a lifted
    /// thumb.
    func testTheTargetReachedStopsTheMarker() {
        steering.steer(towards: aim(80, 116))
        follow(&steering, &game, 4 * Tuning.markerStepTicks)
        XCTAssertEqual(game.marker.pos, point(80, 116))

        let points = follow(&steering, &game, Tuning.fuseDelayTicks)

        XCTAssertEqual(points, [])
        XCTAssertNil(steering.dir(game))
        XCTAssertEqual(game.fuse, Fuse(pos: 0))
    }

    func testLettingGoAimsAtNothing() {
        steering.steer(towards: aim(80, 100))
        XCTAssertEqual(steering.dir(game), .up)

        steering.steer(towards: nil)

        XCTAssertNil(steering.aim)
        XCTAssertNil(steering.dir(game))
    }

    func testAnAimIsRoundedToTheNearestLatticePoint() {
        steering.steer(towards: Vec2(x: 2.4, y: 7.5))

        XCTAssertEqual(steering.aim, Vec2(x: 2.4, y: 7.5))
        XCTAssertEqual(steering.target(on: game.board), point(2, 8))
    }

    func testAnAimOffTheLatticeIsClampedOntoIt() {
        let cases: [(Vec2, Point)] = [
            (Vec2(x: -5, y: 3.6), point(0, 4)),
            (Vec2(x: 1_000, y: -1_000), point(steeringWidth, 0)),
            (Vec2(x: 7, y: 1_000), point(7, steeringHeight)),
            (Vec2(x: -.infinity, y: .infinity), point(0, steeringHeight)),
        ]
        for (aim, target) in cases {
            steering.steer(towards: aim)

            XCTAssertEqual(steering.target(on: game.board), target, "\(aim)")
        }
    }

    /// The marker heads for the clamped target, on the top edge: round the border.
    func testTheMarkerHeadsForTheClampedTarget() {
        steering.steer(towards: Vec2(x: 150, y: -50))

        follow(&steering, &game)

        XCTAssertEqual(game.marker.pos, point(150, 0))
        XCTAssertNil(game.stix)
    }

    func testANaNAimsAtNothing() {
        steering.steer(towards: aim(80, 100))

        for nan in [Vec2(x: .nan, y: 100), Vec2(x: 80, y: .nan)] {
            steering.steer(towards: nan)

            XCTAssertNil(steering.aim, "\(nan)")
            XCTAssertNil(steering.dir(game), "\(nan)")
        }
    }

    /// `(0, 116)` is 84 steps away leftwards and 476 rightwards, `(160, 10)` 190 rightwards and
    /// 370 leftwards, `(90, 0)` 270 rightwards and 290 leftwards, though 120 straight up across
    /// free space.
    func testTheShorterWayRoundTheBorder() {
        let cases: [(Point, Dir, Int)] = [
            (point(0, 116), .left, 84), (point(160, 10), .right, 190), (point(90, 0), .right, 270),
        ]
        for (target, first, steps) in cases {
            var steering = TouchSteering()
            var game = steeringGame()
            steering.steer(towards: Vec2(target))
            XCTAssertEqual(steering.dir(game), first, "\(target)")

            let points = follow(&steering, &game)

            XCTAssertEqual(points.count, steps, "\(target)")
            XCTAssertEqual(points.last, target)
            XCTAssertTrue(points.allSatisfy(game.board.isBorder), "\(target) left the border")
            XCTAssertNil(game.stix, "\(target)")
        }
    }

    /// A block standing on the bottom edge left of the marker makes the way left to `(0, 0)` 438
    /// steps long, against 360 rightwards: the way found on the free board, leftwards, is not
    /// taken.
    func testTheWayRoundIsFoundAgainOnAnotherBoard() {
        steering.steer(towards: aim(0, 0))
        XCTAssertEqual(steering.dir(game), .left)

        game.board = claimedBlock(2 ..< 78, 1 ..< 120)

        XCTAssertEqual(steering.dir(game), .right)
    }

    /// From `(80, 120)`, `(0, 0)` is 200 steps away leftwards and 360 rightwards, `(160, 0)` 200
    /// rightwards and 360 leftwards: the way found to the first target is not kept for the second.
    func testTheWayRoundIsFoundAgainForAnotherTarget() {
        steering.steer(towards: aim(0, 0))
        XCTAssertEqual(steering.dir(game), .left)

        steering.steer(towards: aim(160, 0))

        XCTAssertEqual(steering.dir(game), .right)
    }

    /// A border the marker's own does not lead to (a claimed island, which play never leaves): the
    /// marker draws straight for it instead, and the stix closes there.
    func testABorderTargetTheBorderDoesNotLeadToIsHeadedForStraight() {
        game.board = claimedBlock(78 ..< 82, 100 ..< 104)
        steering.steer(towards: aim(80, 104))

        follow(&steering, &game)

        XCTAssertEqual(game.marker, Marker(pos: point(80, 104), state: .onBorder))
        XCTAssertNil(game.stix)
    }

    /// Back down the stix is refused: the marker goes across first, then down.
    func testARefusedStepGivesWayToTheOtherAxis() {
        drawUp()

        steering.steer(towards: aim(76, 117))
        XCTAssertEqual(steering.dir(game), .left)
        follow(&steering, &game)

        XCTAssertEqual(game.stix?.points, [point(80, 120), point(80, 114), point(76, 114), point(76, 117)])
    }

    func testEveryStepRefusedHoldsNoDirection() {
        drawUp()

        steering.steer(towards: aim(80, 118))

        XCTAssertNil(steering.dir(game))
    }

    /// A target inside a claimed block in the bottom-left corner: the marker walks the border to
    /// the block, then up its side until level with the target, and stops there for good, every
    /// point visited once.
    func testARefusedStepDoesNotLoop() {
        game = steeringGame(claimedBlock(0 ..< 76, 110 ..< 120))
        steering.steer(towards: aim(72, 117))

        let points = follow(&steering, &game)

        XCTAssertEqual(points, [point(79, 120), point(78, 120), point(77, 120), point(76, 120)]
            + [point(76, 119), point(76, 118), point(76, 117)])
        XCTAssertNil(game.stix)
        XCTAssertEqual(follow(&steering, &game, longRun), [])
    }

    /// In the grace period after a death, the marker cannot draw: it heads along the border
    /// instead.
    func testDuringTheGracePeriodTheMarkerHeadsAlongTheBorder() {
        steering.steer(towards: aim(84, 110))
        XCTAssertEqual(steering.dir(game), .up)

        game.graceTicks = Tuning.respawnGraceTicks

        XCTAssertEqual(steering.dir(game), .right)
    }
}
