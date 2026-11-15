import Testing
import XCTest
@testable import QixKit

/// Dimensions of the small board most tests use.
private let width: UInt16 = 4
private let height: UInt16 = 3

private let free = Cell.free
private let fast = Cell.claimed(.fast)
private let slow = Cell.claimed(.slow)
private let outside = Board.outside

private func board() -> Board {
    Board(width: width, height: height)
}

final class BoardTests: XCTestCase {
    func testANewBoardHasItsDimensionsAndOnlyFreeCells() {
        let board = board()
        XCTAssertEqual(board.width, width)
        XCTAssertEqual(board.height, height)
        for y in 0 ..< Int32(height) {
            for x in 0 ..< Int32(width) {
                XCTAssertEqual(board.cell(x: x, y: y), free, "(\(x), \(y))")
            }
        }
    }

    func testEveryCellOffTheBoardIsClaimed() {
        let (columns, rows) = (Int32(width), Int32(height))
        let outsideCells: [(Int32, Int32)] = [
            (-1, 0),
            (0, -1),
            (-1, -1),
            (columns, 0),
            (0, rows),
            (columns, rows),
            (columns - 1, rows),
            (columns, rows - 1),
            (.min, .max),
            (.max, .min),
        ]
        for (x, y) in outsideCells {
            XCTAssertEqual(board().cell(x: x, y: y), outside, "(\(x), \(y))")
        }
        XCTAssert(outside.isClaimed)
    }

    func testAFreshBoardHasNothingClaimed() {
        XCTAssertEqual(board().claimedFraction(), 0)
        XCTAssertEqual(Board(width: Tuning.boardW, height: Tuning.boardH).claimedFraction(), 0)
    }

    func testTheClaimedFractionCountsBothDrawKinds() {
        var board = board()
        board.setCell(x: 0, y: 0, to: fast)
        board.setCell(x: width - 1, y: height - 1, to: slow)
        board.setCell(x: 1, y: 1, to: fast)
        XCTAssertEqual(board.claimedFraction(), 3 / Float(width * height))
    }

    func testAFullyClaimedBoardHasAFractionOfOne() {
        var board = board()
        for y in 0 ..< height {
            for x in 0 ..< width {
                board.setCell(x: x, y: y, to: slow)
            }
        }
        XCTAssertEqual(board.claimedFraction(), 1)
    }

    func testSetCellChangesOnlyThatCell() {
        var board = board()
        board.setCell(x: 2, y: 1, to: slow)
        XCTAssertEqual(board.cell(x: 2, y: 1), slow)
        XCTAssertEqual(board.cell(x: 1, y: 2), free)
        XCTAssertEqual(board.cell(x: 1, y: 1), free)
        XCTAssertEqual(board.cell(x: 2, y: 0), free)
    }

    func testCellsAroundTheCornersHaveOneCellOnTheBoard() {
        let cases: [(Point, [Cell])] = [
            (Point(x: 0, y: 0), [outside, outside, outside, free]),
            (Point(x: width, y: 0), [outside, outside, free, outside]),
            (Point(x: 0, y: height), [outside, free, outside, outside]),
            (Point(x: width, y: height), [free, outside, outside, outside]),
        ]
        for (point, expected) in cases {
            XCTAssertEqual(board().cellsAround(point), expected, "\(point)")
        }
    }

    func testCellsAroundTheEdgesHaveTwoCellsOnTheBoard() {
        let cases: [(Point, [Cell])] = [
            (Point(x: 1, y: 0), [outside, outside, free, free]),
            (Point(x: 1, y: height), [free, free, outside, outside]),
            (Point(x: 0, y: 1), [outside, free, outside, free]),
            (Point(x: width, y: 1), [free, outside, free, outside]),
        ]
        for (point, expected) in cases {
            XCTAssertEqual(board().cellsAround(point), expected, "\(point)")
        }
    }

    func testCellsAroundAnInnerPointComeInReadingOrder() {
        var board = board()
        board.setCell(x: 0, y: 0, to: fast)
        board.setCell(x: 1, y: 1, to: slow)
        XCTAssertEqual(board.cellsAround(Point(x: 1, y: 1)), [fast, free, free, slow])
    }

    func testCellsAroundAPointBeyondTheLatticeAreAllOutside() {
        let far = Point(x: .max, y: .max)
        XCTAssertEqual(board().cellsAround(far), Array(repeating: outside, count: 4))
    }
}

/// Rust's `#[should_panic]` tests, as exit tests (TrapExpectation.swift).
struct BoardTrapTests {
    @Test func settingACellOffTheBoardTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            var board = Board(width: 4, height: 3)
            board.setCell(x: 4, y: 0, to: .claimed(.fast))
        }
        expectMessage(result, "off the 4x3 board")
    }

    @Test func aBoardWithoutCellsTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = Board(width: 0, height: 3)
        }
        expectMessage(result, "empty board 0x3")
    }

    @Test func aBoardWithoutRowsTraps() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            _ = Board(width: 4, height: 0)
        }
        expectMessage(result, "empty board 4x0")
    }
}
