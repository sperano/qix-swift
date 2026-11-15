import XCTest
@testable import QixKit

/// Dimensions of the small board most tests use.
private let width: UInt16 = 4
private let height: UInt16 = 3

private func board() -> Board {
    Board(width: width, height: height)
}

final class MarkerTests: XCTestCase {
    func testStartsOnTheBorderAtTheBottomEdgeCentre() {
        let board = Board(width: Tuning.boardW, height: Tuning.boardH)

        let marker = Marker.start(board)

        XCTAssertEqual(marker.pos, Point(x: Tuning.boardW / 2, y: Tuning.boardH))
        XCTAssertEqual(marker.state, .onBorder)
        XCTAssert(board.isBorder(marker.pos))
    }

    func testStepsAlongABorderEdge() {
        let board = board()
        var marker = Marker.start(board)

        XCTAssert(marker.stepAlongBorder(board, .left))

        XCTAssertEqual(marker.pos, Point(x: width / 2 - 1, y: height))
    }

    func testRefusesAStepIntoFreeSpace() {
        let board = board()
        var marker = Marker.start(board)

        XCTAssertFalse(marker.stepAlongBorder(board, .up))

        XCTAssertEqual(marker.pos, Point(x: width / 2, y: height))
    }

    func testRefusesAStepOffTheBoard() {
        let board = board()
        var marker = Marker.start(board)

        XCTAssertFalse(marker.stepAlongBorder(board, .down))

        XCTAssertEqual(marker.pos, Point(x: width / 2, y: height))
    }

    func testTurnsAtAnOuterCorner() {
        let board = board()
        var marker = Marker(pos: Point(x: 0, y: height), state: .onBorder)

        XCTAssertFalse(marker.stepAlongBorder(board, .left))
        XCTAssert(marker.stepAlongBorder(board, .up))

        XCTAssertEqual(marker.pos, Point(x: 0, y: height - 1))
    }

    func testTurnsAroundAClaimedCell() {
        var board = board()
        board.setCell(x: width - 1, y: height - 1, to: .claimed(.fast))
        var marker = Marker(pos: Point(x: width - 1, y: height), state: .onBorder)

        XCTAssertFalse(marker.stepAlongBorder(board, .right))
        XCTAssert(marker.stepAlongBorder(board, .up))
        XCTAssertFalse(marker.stepAlongBorder(board, .up))
        XCTAssert(marker.stepAlongBorder(board, .right))

        XCTAssertEqual(marker.pos, Point(x: width, y: height - 1))
    }
}
