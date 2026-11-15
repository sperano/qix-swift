import XCTest
@testable import QixKit

/// Dimensions of the boards: the marker starts at `(width / 2, height)`, and the stix runs straight
/// along column `width / 2` from one edge to the other.
private let width: UInt16 = 20
private let height: UInt16 = 10

/// The free column holding the Qix when it is left of the stix, and when it is right of it: `penned`
/// keeps the Qix in it.
private let leftColumn: UInt16 = 3
private let rightColumn: UInt16 = 16

/// The lattice column of the second stix of `testClaimsAddUpInTheScore`: between the Qix's column
/// and the first stix, on the side the first claim left free.
private let secondStixX: UInt16 = 7

/// A free `width x height` board but for the walls of `column`.
private func walledBoard(_ column: UInt16) -> Board {
    penned(width, height, column).0
}

/// A game on the board walled around `column`, with a vertical Qix down the middle of the column,
/// too long to turn between its walls.
private func gameWithQixIn(_ column: UInt16) -> Game {
    let (board, qix) = penned(width, height, column)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// A game on a free `width x height` board but for the walls of both `leftColumn` and `rightColumn`,
/// with a Qix penned in each: the left one first in the game's list, or the right one.
private func gameWithQixEitherSide(leftFirst: Bool) -> Game {
    var (board, left) = penned(width, height, leftColumn)
    let (rightWalls, right) = penned(width, height, rightColumn)
    for (x, y) in (0 ..< width).flatMap({ x in (0 ..< height).map { y in (x, y) } }) {
        let cell = rightWalls.cell(x: Int32(x), y: Int32(y))
        if cell.isClaimed {
            board.setCell(x: x, y: y, to: cell)
        }
    }
    let qix: [Qix] = leftFirst ? [left, right] : [right, left]
    return Game(board: board, qix: qix, sparx: [], rng: Rng(seed: gameSeed))
}

/// Draws the stix up from the marker's start to the top edge.
private func closeFromBottom(_ game: inout Game) {
    draw(&game, .up, .fast, UInt32(height))
}

/// Walks the marker round the left and top edges to the top of its column, then draws the stix down
/// to the bottom edge.
private func closeFromTop(_ game: inout Game) {
    let half = UInt32(width / 2)
    walk(&game, .left, half)
    walk(&game, .up, UInt32(height))
    walk(&game, .right, half)
    draw(&game, .down, .fast, UInt32(height))
}

/// Every cell on the Qix's side of the stix, `x < width / 2` when `column` is left of it, is as
/// `walledBoard` left it; every cell on the other side is claimed.
private func assertQixSideKept(_ game: Game, _ column: UInt16) {
    let qixLeft = column < width / 2
    let (cellX, _) = game.qix[0].cell
    XCTAssertEqual(cellX, column, "the Qix left its column")
    let kept = walledBoard(column)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let (cx, cy) = (Int32(x), Int32(y))
            let cell = game.board.cell(x: cx, y: cy)
            if (x < width / 2) == qixLeft {
                XCTAssertEqual(cell, kept.cell(x: cx, y: cy), "(\(x), \(y)) on the Qix side")
            } else {
                XCTAssert(cell.isClaimed, "(\(x), \(y)) is free")
            }
        }
    }
}

/// The cells of `board` that are claimed.
private func claimedCount(_ board: Board) -> UInt32 {
    let cells = (0 ..< height).flatMap { y in (0 ..< width).map { x in (Int32(x), Int32(y)) } }
    let claimed = cells.filter { board.cell(x: $0.0, y: $0.1).isClaimed }.count
    return UInt32(claimed)
}

/// The cells the stix up from the bottom claims, drawn `kind`, in a game with the Qix left of it, and
/// the points the game scores for them.
private func claimFromBottom(_ kind: DrawKind) -> (UInt32, UInt32) {
    var game = gameWithQixIn(leftColumn)
    let before = claimedCount(game.board)
    XCTAssertEqual(game.score.points, 0)

    draw(&game, .up, kind, UInt32(height))

    XCTAssertNil(game.stix)
    let cells = claimedCount(game.board) - before
    return (cells, game.score.points)
}

/// Closing a stix through `Game.tick`: the side holding the Qix stays free.
final class GameClaimsTests: XCTestCase {
    func testAQixLeftOfAStixDrawnFromTheBottomKeepsTheLeft() {
        var game = gameWithQixIn(leftColumn)

        closeFromBottom(&game)

        XCTAssertNil(game.stix)
        assertQixSideKept(game, leftColumn)
    }

    func testAQixRightOfAStixDrawnFromTheBottomKeepsTheRight() {
        var game = gameWithQixIn(rightColumn)

        closeFromBottom(&game)

        XCTAssertNil(game.stix)
        assertQixSideKept(game, rightColumn)
    }

    func testAQixLeftOfAStixDrawnFromTheTopKeepsTheLeft() {
        var game = gameWithQixIn(leftColumn)

        closeFromTop(&game)

        XCTAssertNil(game.stix)
        assertQixSideKept(game, leftColumn)
    }

    func testAQixRightOfAStixDrawnFromTheTopKeepsTheRight() {
        var game = gameWithQixIn(rightColumn)

        closeFromTop(&game)

        XCTAssertNil(game.stix)
        assertQixSideKept(game, rightColumn)
    }

    func testAFastClaimScoresItsCellsAtTheStartingMultiplier() {
        let (cells, points) = claimFromBottom(.fast)

        XCTAssert(cells > 0)
        XCTAssertEqual(points, cells * Tuning.pointsPerCell * Tuning.startingMultiplier)
    }

    func testASlowClaimScoresTheSlowDrawFactorTimesMore() {
        let (cells, points) = claimFromBottom(.slow)

        XCTAssert(cells > 0)
        XCTAssertEqual(points, cells * Tuning.pointsPerCell * Tuning.startingMultiplier * Tuning.slowDrawFactor)
    }

    func testClaimsAddUpInTheScore() {
        var game = gameWithQixIn(leftColumn)
        let before = claimedCount(game.board)
        closeFromBottom(&game)
        let first = claimedCount(game.board) - before

        walk(&game, .left, UInt32(width / 2 - secondStixX))
        draw(&game, .down, .fast, UInt32(height))

        XCTAssertNil(game.stix)
        let second = claimedCount(game.board) - before - first
        XCTAssert(first > 0 && second > 0)
        XCTAssertEqual(game.score.points, (first + second) * Tuning.pointsPerCell * Tuning.startingMultiplier)
    }

    func testAStixBetweenTwoQixClaimsNothing() {
        for leftFirst in [true, false] {
            var game = gameWithQixEitherSide(leftFirst: leftFirst)
            let board = game.board

            closeFromBottom(&game)

            let top = Point(x: width / 2, y: 0)
            XCTAssertEqual(game.marker.pos, top, "\(leftFirst): marker died")
            XCTAssertEqual(game.lives, Tuning.startingLives, "\(leftFirst)")
            XCTAssertNil(game.stix, "\(leftFirst)")
            XCTAssertEqual(game.board, board, "\(leftFirst)")
            XCTAssertEqual(game.score.points, 0, "\(leftFirst)")
        }
    }
}
