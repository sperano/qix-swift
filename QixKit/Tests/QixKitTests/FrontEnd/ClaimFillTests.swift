import XCTest
@testable import QixKit

/// Dimensions of the small board the tests use.
private let fillW: UInt16 = 6
private let fillH: UInt16 = 4

/// A `fillW x fillH` board with the cells `cells` claimed as given.
private func fillBoard(_ cells: [(UInt16, UInt16, Cell)]) -> Board {
    var board = Board(width: fillW, height: fillH)
    for (x, y, cell) in cells {
        board.setCell(x: x, y: y, to: cell)
    }
    return board
}

private let fastCell = Cell.claimed(.fast)
private let slowCell = Cell.claimed(.slow)

final class ClaimFillTests: XCTestCase {
    func testANewAnimationRunsNothing() {
        let fill = ClaimFill(board: fillBoard([(0, 0, fastCell)]))

        XCTAssertNil(fill.fresh)
    }

    func testAnUnchangedBoardStartsNothing() {
        let board = fillBoard([(0, 0, fastCell)])
        var fill = ClaimFill(board: board)

        fill.tick(board)

        XCTAssertNil(fill.fresh)
    }

    func testAClaimAnimatesOnlyTheCellsItTook() throws {
        var fill = ClaimFill(board: fillBoard([(0, 0, fastCell)]))

        fill.tick(fillBoard([(0, 0, fastCell), (1, 0, slowCell), (2, 0, slowCell), (4, 2, fastCell)]))

        let fresh = try XCTUnwrap(fill.fresh)
        XCTAssertEqual(
            fresh.runs,
            [CellRun(row: 0, cols: 1 ..< 3, kind: .slow), CellRun(row: 2, cols: 4 ..< 5, kind: .fast)]
        )
        XCTAssertEqual(fresh.progress, 0)
    }

    func testTheAnimationMovesOnOneStepATickAndEndsAfterItsTicks() throws {
        let claimed = fillBoard([(3, 3, fastCell)])
        var fill = ClaimFill(board: Board(width: fillW, height: fillH))
        fill.tick(claimed)

        for done in 1 ..< ClaimFill.claimFillTicks {
            fill.tick(claimed)

            let progress = try XCTUnwrap(fill.fresh, "the animation runs").progress
            XCTAssertEqual(progress, Float(done) / Float(ClaimFill.claimFillTicks))
        }
        fill.tick(claimed)
        XCTAssertNil(fill.fresh)
    }

    func testANewClaimReplacesTheRunningAnimation() throws {
        let first = fillBoard([(0, 0, fastCell)])
        let second = fillBoard([(0, 0, fastCell), (5, 3, slowCell)])
        var fill = ClaimFill(board: Board(width: fillW, height: fillH))
        fill.tick(first)
        fill.tick(first)

        fill.tick(second)

        let fresh = try XCTUnwrap(fill.fresh, "the animation runs")
        XCTAssertEqual(fresh.progress, 0)
        XCTAssertEqual(fresh.runs, [CellRun(row: 3, cols: 5 ..< 6, kind: .slow)])
    }

    func testABoardThatLostClaimedCellsStopsTheAnimation() {
        let claimed = fillBoard([(0, 0, fastCell)])
        var fill = ClaimFill(board: Board(width: fillW, height: fillH))
        fill.tick(claimed)

        fill.tick(fillBoard([(1, 1, fastCell)]))

        XCTAssertNil(fill.fresh)
    }

    func testABoardOfAnotherSizeStartsNothing() {
        var fill = ClaimFill(board: Board(width: fillW, height: fillH))
        var larger = Board(width: fillW + 1, height: fillH)
        larger.setCell(x: 0, y: 0, to: fastCell)

        fill.tick(larger)

        XCTAssertNil(fill.fresh)
    }

    func testAClaimAfterAResetIsComparedWithTheNewBoard() throws {
        var fill = ClaimFill(board: fillBoard([(0, 0, fastCell)]))
        fill.tick(Board(width: fillW, height: fillH))

        fill.tick(fillBoard([(2, 2, fastCell)]))

        XCTAssertEqual(
            try XCTUnwrap(fill.fresh, "the animation runs").runs,
            [CellRun(row: 2, cols: 2 ..< 3, kind: .fast)]
        )
    }
}

/// The colours of the animation: qix-rs's `render/claim_fill_test.rs`, without the painting.
final class ClaimFillColourTests: XCTestCase {
    /// The steps `testTheColourMovesFromTheFlashTowardsTheFill` samples the animation at.
    private static let steps = 4

    func testTheAnimationStartsOnTheFlash() {
        for kind in [DrawKind.fast, .slow] {
            XCTAssertEqual(BoardShapes.fillColour(kind, progress: 0), Palette.claimFlash)
        }
    }

    func testTheAnimationEndsOnTheFillOfTheKind() {
        for kind in [DrawKind.fast, .slow] {
            XCTAssertEqual(BoardShapes.fillColour(kind, progress: 1), Palette.fill(kind))
        }
    }

    func testProgressOutsideTheAnimationIsClamped() {
        XCTAssertEqual(BoardShapes.fillColour(.slow, progress: -1), BoardShapes.fillColour(.slow, progress: 0))
        XCTAssertEqual(BoardShapes.fillColour(.slow, progress: 2), BoardShapes.fillColour(.slow, progress: 1))
    }

    /// Eased, so a quarter of the way the colour is 7/16 of the way to the fill: the blue channel
    /// of the fast fill goes from 255 to 165, so it is at 255 - 90 * 7 / 16 = 215.6, rounded up.
    func testTheAnimationEasesOutTowardsTheFill() {
        XCTAssertEqual(BoardShapes.fillColour(.fast, progress: 0.25).blue, 216)
    }

    func testTheColourMovesFromTheFlashTowardsTheFill() {
        let fill = Palette.fill(.fast)
        let distance = { (colour: RGBA) in
            [(colour.red, fill.red), (colour.green, fill.green), (colour.blue, fill.blue)]
                .map { abs(Int($0.0) - Int($0.1)) }
                .reduce(0, +)
        }

        let distances = (0 ... Self.steps).map {
            distance(BoardShapes.fillColour(.fast, progress: Float($0) / Float(Self.steps)))
        }

        XCTAssertEqual(distances, distances.sorted(by: >))
        XCTAssertEqual(Set(distances).count, distances.count, "\(distances)")
    }
}
