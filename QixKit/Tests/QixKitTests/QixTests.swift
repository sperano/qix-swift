import XCTest
@testable import QixKit

/// Seed of the runs that need one fixed seed.
private let seed: UInt64 = 1_193

/// Ticks of the long runs.
private let longRunTicks: UInt32 = 10_000

/// Spacing of the points the free-cell check samples along a segment, independently of the cell
/// walk the Qix uses.
private let sampleSpacing: Float = 0.05

/// Rounding slack on speeds and lengths.
private let epsilon: Float = 1e-4

/// Ticks of the claimed-area run in which the Qix must touch each claimed area of
/// `boardWithClaims`, so the run exercises the bounces off them.
private let minTicksBesideEachClaim: UInt32 = 10

/// A speed range entirely above `Tuning.qixSpeed`, as a later level's.
private let fastSpeed: ClosedRange<Float> = 0.9 ... 1.0

/// Ticks of the `Qix.previous` test: past the second, the segment one tick ago is no longer the
/// oldest of the trail.
private let previousTicks = 3

/// The free row of the corridor test, between claimed rows, and where its Qix starts along it.
private let corridorRow: UInt16 = 20
private let corridorStartX: Float = 10.5

/// The corridor Qix's velocity, mostly across the corridor so every mirror of it leaves the row.
private let acrossCorridor = Vec2(x: 0.3, y: 0.7)

/// Where on the middle row the spawn test centres its Qix.
private let spawnX: Float = 40.0

/// Offsets, within its cell, of the ends of the `qixAt` Qix.
private let stillQixEnds: (Float, Float) = (0.25, 0.75)

/// A still, short, level Qix across the middle of cell `(x, y)`, so its `Qix.cell` is `(x, y)`.
func qixAt(_ cell: (UInt16, UInt16)) -> Qix {
    let (x, midY) = (Float(cell.0), Float(cell.1) + 0.5)
    let (left, right) = stillQixEnds
    return Qix(a: Vec2(x: x + left, y: midY), b: Vec2(x: x + right, y: midY), vel: Vec2(), spin: 0)
}

/// A cell of the board, as `(x, y)`.
private struct Spot: Equatable {
    let x: Int32
    let y: Int32
}

/// The claimed block in the middle of `boardWithClaims`.
private func inBlock(_ x: Int32, _ y: Int32) -> Bool {
    (60 ..< 100).contains(x) && (40 ..< 80).contains(y)
}

/// The claimed bottom-left corner of `boardWithClaims`.
private func inCorner(_ x: Int32, _ y: Int32) -> Bool {
    x < 40 && y >= 80
}

/// A full-size board with claimed areas the Qix must bounce off: a block in the middle and the
/// bottom-left corner, as a claim leaves them.
private func boardWithClaims() -> Board {
    var board = Board(width: Tuning.boardW, height: Tuning.boardH)
    let claimed = Cell.claimed(.fast)
    for y in 0 ..< Tuning.boardH {
        for x in 0 ..< Tuning.boardW {
            let (cx, cy) = (Int32(x), Int32(y))
            if inBlock(cx, cy) || inCorner(cx, cy) {
                board.setCell(x: x, y: y, to: claimed)
            }
        }
    }
    return board
}

/// A Qix lying along a free row of `boardWithClaims`, heading down and right.
private func qixBesideTheClaims() -> Qix {
    let start = Vec2(x: 10.5, y: 20.5)
    return Qix(a: start, b: start + Vec2(x: Tuning.qixLength, y: 0), vel: Vec2(x: 0.4, y: 0.3), spin: 0)
}

/// The cell of `board` under `point`, off the board reading as claimed.
private func boardCell(_ board: Board, _ point: Vec2) -> Cell {
    board.cell(x: Int32(point.x.rounded(.down)), y: Int32(point.y.rounded(.down)))
}

/// Points along the Qix's segment, `sampleSpacing` apart or closer, both ends included.
private func samplePoints(_ qix: Qix) -> [Vec2] {
    let (start, end) = (qix.a, qix.b)
    let samples = UInt32(((end - start).length / sampleSpacing).rounded(.up))
    return (0 ... samples).map { start + (end - start) * (Float($0) / Float(samples)) }
}

/// Whether a claimed cell of `board` in `area` is next to, on a side or a corner, the cell under a
/// sampled point of the Qix's segment.
private func beside(_ board: Board, _ qix: Qix, _ area: (Int32, Int32) -> Bool) -> Bool {
    func onBoard(_ x: Int32, _ y: Int32) -> Bool {
        (0 ..< Int32(board.width)).contains(x) && (0 ..< Int32(board.height)).contains(y)
    }
    var cells: [Spot] = []
    for point in samplePoints(qix) {
        let spot = Spot(x: Int32(point.x.rounded(.down)), y: Int32(point.y.rounded(.down)))
        if cells.last != spot {
            cells.append(spot)
        }
    }
    let offsets: ClosedRange<Int32> = -1 ... 1
    return cells.contains { spot in
        offsets.contains { dy in
            offsets.contains { dx in
                let (nx, ny) = (spot.x + dx, spot.y + dy)
                return onBoard(nx, ny) && area(nx, ny) && board.cell(x: nx, y: ny) != .free
            }
        }
    }
}

/// Every sampled point of the Qix's segment, and the cell under its midpoint, is a free cell of
/// `board`.
private func assertOnFreeCells(_ board: Board, _ qix: Qix, _ tick: UInt32) {
    for point in samplePoints(qix) {
        let cell = boardCell(board, point)
        XCTAssertEqual(cell, .free, "tick \(tick): \(point) of \(qix)")
    }
    let (x, y) = qix.cell
    let mid = board.cell(x: Int32(x), y: Int32(y))
    XCTAssertEqual(mid, .free, "tick \(tick): midpoint of \(qix)")
}

/// Ticks `qix` on `board` for `ticks` ticks, calling `check` after each (`run` in qix-rs, which
/// XCTestCase.run would hide).
private func runQix(_ board: Board, _ qix: inout Qix, _ ticks: UInt32, check: (Qix, UInt32) -> Void) {
    var rng = Rng(seed: seed)
    for tick in 0 ..< ticks {
        qix.tick(board, &rng)
        check(qix, tick)
    }
}

final class QixTests: XCTestCase {
    func testStaysInFreeCellsOfAFreshBoardOverTenThousandTicks() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        var rng = Rng(seed: seed)
        var qix = Qix.spawn(board, &rng)

        runQix(board, &qix, longRunTicks) { qix, tick in
            assertOnFreeCells(board, qix, tick)
        }
    }

    func testStaysInFreeCellsAroundClaimedAreasOverTenThousandTicks() {
        let board = boardWithClaims()
        var qix = qixBesideTheClaims()
        var (besideBlock, besideCorner): (UInt32, UInt32) = (0, 0)

        runQix(board, &qix, longRunTicks) { qix, tick in
            assertOnFreeCells(board, qix, tick)
            besideBlock += beside(board, qix, inBlock) ? 1 : 0
            besideCorner += beside(board, qix, inCorner) ? 1 : 0
        }
        XCTAssertGreaterThanOrEqual(besideBlock, minTicksBesideEachClaim)
        XCTAssertGreaterThanOrEqual(besideCorner, minTicksBesideEachClaim)
    }

    func testKeepsItsLengthSpeedAndSpinWithinBounds() {
        let board = boardWithClaims()
        var qix = qixBesideTheClaims()

        runQix(board, &qix, longRunTicks) { qix, tick in
            let (length, speed) = ((qix.b - qix.a).length, qix.vel.length)
            XCTAssertLessThan(abs(length - Tuning.qixLength), epsilon, "tick \(tick): \(length)")
            let bounds = Tuning.qixSpeed.lowerBound - epsilon ... Tuning.qixSpeed.upperBound + epsilon
            XCTAssert(bounds.contains(speed), "tick \(tick): speed \(speed)")
            XCTAssertLessThanOrEqual(abs(qix.spin), Tuning.qixMaxSpin, "tick \(tick): \(qix.spin)")
        }
    }

    func testTheTrailHoldsTheLastSegmentsUpToItsLength() {
        let board = boardWithClaims()
        var qix = qixBesideTheClaims()
        var segments = [(qix.a, qix.b)]
        XCTAssertEqual(qix.trail.count, 1)

        runQix(board, &qix, longRunTicks) { qix, _ in
            segments.append((qix.a, qix.b))
            let expected = segments[max(segments.count - Tuning.qixTrailLen, 0)...]
            XCTAssert(qix.trail.elementsEqual(expected) { $0 == $1 })
        }
        XCTAssertEqual(qix.trail.count, Tuning.qixTrailLen)
    }

    func testASeedFixesThePath() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        func path(_ seed: UInt64) -> Qix {
            var rng = Rng(seed: seed)
            var qix = Qix.spawn(board, &rng)
            for _ in 0 ..< longRunTicks {
                qix.tick(board, &rng)
            }
            return qix
        }

        XCTAssertEqual(path(seed), path(seed))
        XCTAssertNotEqual(path(seed), path(seed + 1))
    }

    func testBouncesOffTheEdgeOfTheBoard() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        let x = Float(Tuning.boardW) - 0.5
        let start = Vec2(x: x, y: 10.5)
        let speed = Tuning.qixSpeed.upperBound
        var qix = Qix(a: start, b: start + Vec2(x: 0, y: Tuning.qixLength), vel: Vec2(x: speed, y: 0), spin: 0)
        var rng = Rng(seed: seed)

        qix.tick(board, &rng)

        XCTAssertLessThan(qix.vel.x, 0, "\(qix)")
        assertOnFreeCells(board, qix, 0)
    }

    func testBouncesOffAClaimedCell() {
        var board = Board(width: Tuning.boardW, height: Tuning.boardH)
        let wall: UInt16 = 30
        for y in 0 ..< Tuning.boardH {
            board.setCell(x: wall, y: y, to: .claimed(.slow))
        }
        let start = Vec2(x: Float(wall) - 0.5, y: 10.5)
        let speed = Tuning.qixSpeed.upperBound
        var qix = Qix(a: start, b: start + Vec2(x: 0, y: Tuning.qixLength), vel: Vec2(x: speed, y: 0), spin: 0)
        var rng = Rng(seed: seed)

        qix.tick(board, &rng)

        XCTAssertLessThan(qix.vel.x, 0, "\(qix)")
        assertOnFreeCells(board, qix, 0)
    }

    func testStaysPutAndReversesWhenNoMirrorIsFree() {
        var board = Board(width: Tuning.boardW, height: Tuning.boardH)
        for x in 0 ..< Tuning.boardW {
            board.setCell(x: x, y: corridorRow - 1, to: .claimed(.slow))
            board.setCell(x: x, y: corridorRow + 1, to: .claimed(.slow))
        }
        let start = Vec2(x: corridorStartX, y: Float(corridorRow) + 0.5)
        let end = start + Vec2(x: Tuning.qixLength, y: 0)
        var qix = Qix(a: start, b: end, vel: acrossCorridor, spin: Tuning.qixMaxSpin)
        var rng = Rng(seed: seed)

        qix.tick(board, &rng)

        XCTAssertEqual(qix.a, start, "\(qix)")
        XCTAssertEqual(qix.b, end, "\(qix)")
        XCTAssertLessThan(qix.vel.x, 0, "\(qix)")
        XCTAssertLessThan(qix.vel.y, 0, "\(qix)")
        XCTAssertLessThan(qix.spin, 0, "\(qix)")
    }

    func testSpawnsCentredOnTheBoardWithinTheSpeedBounds() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        var rng = Rng(seed: seed)

        let qix = Qix.spawn(board, &rng)

        let centre = Vec2(x: Float(Tuning.boardW), y: Float(Tuning.boardH)) * 0.5
        XCTAssertLessThan((qix.a.midpoint(qix.b) - centre).length, epsilon)
        XCTAssertLessThan(abs((qix.b - qix.a).length - Tuning.qixLength), epsilon)
        XCTAssert(Tuning.qixSpeed.contains(qix.vel.length), "\(qix)")
        XCTAssertEqual(qix.trail.count, 1)
    }

    func testItsCellIsTheCellUnderItsMidpoint() {
        let qix = Qix(a: Vec2(x: 2.5, y: 3.2), b: Vec2(x: 6.9, y: 3.6), vel: Vec2(), spin: 0)

        XCTAssert(qix.cell == (4, 3), "\(qix.cell)")
    }

    /// Swift only: Rust's `as u16` saturates where Swift's conversion would trap, so `Qix.cell`
    /// clamps a midpoint off the coordinate range, and reads NaN as zero.
    func testTheCellOfAMidpointOffTheCoordinateRangeSaturatesAsRustCastsIt() {
        let beyond = Float(UInt16.max) + 1
        let offRange = Qix(a: Vec2(x: -beyond, y: beyond), b: Vec2(x: -beyond, y: beyond), vel: Vec2(), spin: 0)
        let nan = Qix(a: Vec2(x: .nan, y: .nan), b: Vec2(x: .nan, y: .nan), vel: Vec2(), spin: 0)

        XCTAssert(offRange.cell == (0, .max), "\(offRange.cell)")
        XCTAssert(nan.cell == (0, 0), "\(nan.cell)")
    }

    func testAQixSpawnedAtAPointIsCentredOnIt() {
        let centre = Vec2(x: spawnX, y: Float(Tuning.boardH) * 0.5)
        var rng = Rng(seed: seed)

        let qix = Qix.spawnAt(centre, Tuning.qixSpeed, &rng)

        XCTAssertLessThan((qix.a.midpoint(qix.b) - centre).length, epsilon)
        XCTAssertLessThan(abs((qix.b - qix.a).length - Tuning.qixLength), epsilon)
    }

    func testASpawnedQixKeepsWithinItsSpeedRange() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        let centre = Vec2(x: Float(Tuning.boardW), y: Float(Tuning.boardH)) * 0.5
        var rng = Rng(seed: seed)
        var qix = Qix.spawnAt(centre, fastSpeed, &rng)
        XCTAssertEqual(qix.speed, fastSpeed)
        let bounds = fastSpeed.lowerBound - epsilon ... fastSpeed.upperBound + epsilon
        XCTAssert(bounds.contains(qix.vel.length))

        runQix(board, &qix, longRunTicks) { qix, tick in
            let speed = qix.vel.length
            XCTAssert(bounds.contains(speed), "tick \(tick): speed \(speed)")
        }
    }

    func testThePreviousSegmentIsTheOneBeforeTheLastTick() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)
        var rng = Rng(seed: seed)
        var qix = qixAt((1, 1))
        var segments = [(qix.a, qix.b)]
        XCTAssert(qix.previous == segments[0], "before any tick")

        for tick in 0 ..< previousTicks {
            qix.tick(board, &rng)
            segments.append((qix.a, qix.b))
            XCTAssert(segments[tick + 1] != segments[tick], "tick \(tick): still")
            XCTAssert(qix.previous == segments[tick], "tick \(tick)")
        }
    }
}
