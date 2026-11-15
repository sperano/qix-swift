import XCTest
@testable import QixKit

/// Dimensions of the small board the tests use.
private let shapesW: UInt16 = 6
private let shapesH: UInt16 = 4

/// Side of the board of `drawingGame`, large enough for its stix to stay clear of the Qix.
private let drawingSide: UInt16 = 20

/// Seed of every game the tests play.
private let shapesSeed: UInt64 = 1

private func segment(_ from: (UInt16, UInt16), _ to: (UInt16, UInt16)) -> LatticeSegment {
    LatticeSegment(from: Point(x: from.0, y: from.1), to: Point(x: to.0, y: to.1))
}

/// A `shapesW x shapesH` board with the cells of each `(rows, cols, kind)` block claimed by `kind`.
private func boardWith(_ blocks: [(Range<UInt16>, Range<UInt16>, DrawKind)]) -> Board {
    var board = Board(width: shapesW, height: shapesH)
    for (rows, cols, kind) in blocks {
        for y in rows {
            for x in cols {
                board.setCell(x: x, y: y, to: .claimed(kind))
            }
        }
    }
    return board
}

private func point(_ x: UInt16, _ y: UInt16) -> Point {
    Point(x: x, y: y)
}

/// A game on a free `drawingSide` square board with a still Qix in its top-right cell and no Sparx.
private func drawingGame() -> Game {
    Game(
        board: Board(width: drawingSide, height: drawingSide), qix: [qixAt((drawingSide - 1, 0))], sparx: [],
        rng: Rng(seed: shapesSeed)
    )
}

final class BoardShapesTests: XCTestCase {
    func testTheBorderOfAFreshBoardIsItsFourSides() {
        XCTAssertEqual(
            BoardShapes.borderSegments(Board(width: shapesW, height: shapesH)),
            [
                segment((0, 0), (shapesW, 0)),
                segment((0, shapesH), (shapesW, shapesH)),
                segment((0, 0), (0, shapesH)),
                segment((shapesW, 0), (shapesW, shapesH)),
            ]
        )
    }

    func testAClaimedCornerMovesTheBorderAroundIt() {
        XCTAssertEqual(
            BoardShapes.borderSegments(boardWith([(0 ..< 2, 0 ..< 3, .fast)])),
            [
                segment((3, 0), (shapesW, 0)),
                segment((0, 2), (3, 2)),
                segment((0, shapesH), (shapesW, shapesH)),
                segment((0, 2), (0, shapesH)),
                segment((3, 0), (3, 2)),
                segment((shapesW, 0), (shapesW, shapesH)),
            ]
        )
    }

    func testClaimedCellsOfBothKindsHaveNoBorderBetweenThem() {
        let board = boardWith([(0 ..< shapesH, 0 ..< 3, .fast), (0 ..< shapesH, 3 ..< shapesW, .slow)])

        XCTAssertEqual(BoardShapes.borderSegments(board), [])
    }

    func testAStixWithoutSegmentsHasNoRuns() {
        XCTAssertEqual(BoardShapes.stixRuns(Stix(start: point(2, shapesH))), [])
    }

    func testStixSegmentsOfOneKindFormOnePolyline() {
        var stix = Stix(start: point(2, shapesH))
        stix.push(point(2, 2), .fast)
        stix.push(point(4, 2), .fast)

        XCTAssertEqual(
            BoardShapes.stixRuns(stix),
            [StixRun(kind: .fast, points: [point(2, shapesH), point(2, 2), point(4, 2)])]
        )
    }

    func testAChangeOfKindStartsAPolylineAtTheLastPoint() {
        var stix = Stix(start: point(2, shapesH))
        stix.push(point(2, 2), .slow)
        stix.push(point(4, 2), .fast)
        stix.push(point(4, 1), .fast)
        stix.push(point(5, 1), .slow)

        XCTAssertEqual(
            BoardShapes.stixRuns(stix),
            [
                StixRun(kind: .slow, points: [point(2, shapesH), point(2, 2)]),
                StixRun(kind: .fast, points: [point(2, 2), point(4, 2), point(4, 1)]),
                StixRun(kind: .slow, points: [point(4, 1), point(5, 1)]),
            ]
        )
    }

    func testTheMarkerIsPlainUntilTheStixHasASegment() {
        XCTAssertEqual(BoardShapes.markerInner(nil), Palette.marker)
        XCTAssertEqual(BoardShapes.markerInner(Stix(start: point(2, shapesH))), Palette.marker)
    }

    func testTheMarkerTakesTheColourOfTheKindOfTheLastSegment() {
        var stix = Stix(start: point(2, shapesH))
        stix.push(point(2, 2), .fast)
        XCTAssertEqual(BoardShapes.markerInner(stix), Palette.fastStix)

        stix.push(point(3, 2), .slow)
        XCTAssertEqual(BoardShapes.markerInner(stix), Palette.slowStix)
    }

    func testClaimedPixelsAreTheFillsOfTheirKindsRowByRowAndFreeCellsTransparent() {
        var board = Board(width: 3, height: 2)
        // Column by column, the fast cell would be the third pixel.
        board.setCell(x: 1, y: 0, to: .claimed(.fast))
        board.setCell(x: 2, y: 1, to: .claimed(.slow))
        let (fast, slow, free) = (Palette.fastFill, Palette.slowFill, RGBA.transparent)

        let expected = [free, fast, free, free, free, slow].flatMap { [$0.red, $0.green, $0.blue, $0.alpha] }
        XCTAssertEqual(BoardShapes.claimedPixels(board), expected)
    }

    func testAFullBoardHasOnePixelPerCell() {
        let pixels = BoardShapes.claimedPixels(Board(width: Tuning.boardW, height: Tuning.boardH))

        XCTAssertEqual(pixels.count, Int(Tuning.boardW) * Int(Tuning.boardH) * BoardShapes.bytesPerPixel)
    }
}

final class EnemyShapesTests: XCTestCase {
    private let trail = Palette.qixTrail

    func testAFreshTrailHasTheFirstColour() {
        XCTAssertEqual(BoardShapes.trailColours(1, ticks: 0), [trail[0]])
    }

    func testEachSegmentTakesTheNextColourOldestFirst() {
        XCTAssertEqual(BoardShapes.trailColours(3, ticks: 2), Array(trail[..<3]))
    }

    func testTheColoursWrapAroundThePalette() {
        let count = trail.count + 2

        let expected = (0 ..< count).map { trail[$0 % trail.count] }
        XCTAssertEqual(BoardShapes.trailColours(count, ticks: UInt64(count - 1)), expected)
    }

    func testASegmentKeepsItsColourWhileTheTrailMovesOn() {
        for ticks in UInt64(0) ..< UInt64(2 * trail.count) {
            let before = BoardShapes.trailColours(Tuning.qixTrailLen, ticks: ticks + 100)
            let after = BoardShapes.trailColours(Tuning.qixTrailLen, ticks: ticks + 101)

            XCTAssertEqual(Array(after.dropLast()), Array(before.dropFirst()), "at tick \(ticks)")
        }
    }

    func testATrailLongerThanTheTicksStillCyclesBackwards() {
        XCTAssertEqual(BoardShapes.trailColours(2, ticks: 0), [trail[trail.count - 1], trail[0]])
    }

    func testNoFuseIsDrawnWhileItIsOut() {
        XCTAssertNil(BoardShapes.fusePoint(drawingGame()))
    }

    func testNoFuseIsDrawnOnAStixBeforeItIsLit() {
        var game = drawingGame()
        draw(&game, .up, .fast, 3)
        stand(&game, Tuning.fuseDelayTicks - 1)

        XCTAssertNotNil(game.stix)
        XCTAssertNil(BoardShapes.fusePoint(game))
    }

    func testALitFuseIsDrawnAtTheStartOfTheStix() throws {
        var game = drawingGame()
        draw(&game, .up, .fast, 3)
        stand(&game, Tuning.fuseDelayTicks)

        XCTAssertEqual(BoardShapes.fusePoint(game), try XCTUnwrap(game.stix).start)
    }

    func testTheFuseIsDrawnOnTheStixPointItHasBurntTo() throws {
        var game = drawingGame()
        draw(&game, .up, .fast, 2)
        draw(&game, .left, .fast, 2)
        stand(&game, Tuning.fuseDelayTicks + Tuning.fuseStepTicks)

        let stix = try XCTUnwrap(game.stix)
        XCTAssertEqual(stix.points.count, 3)
        XCTAssertEqual(BoardShapes.fusePoint(game), stix.points[1])
    }
}
