import XCTest
@testable import QixKit

/// Dimensions of the small board most tests use.
private let width: UInt16 = 4
private let height: UInt16 = 3

/// The smallest number of border neighbours a border point can have: the border never dead-ends.
private let minBorderNeighbours = 2

/// The border neighbours of every border point of a fresh board: the two along its side.
private let sideNeighbours = 2

private let fast = Cell.claimed(.fast)
private let slow = Cell.claimed(.slow)

/// A unit lattice edge, as one end and the step from there.
private struct Edge: Hashable {
    let point: Point
    let dir: Dir
}

/// A border neighbour, as `Board.borderNeighbours` lists it.
private struct Neighbour: Equatable {
    let dir: Dir
    let next: Point
}

private func board() -> Board {
    Board(width: width, height: height)
}

/// Every point of the board's `(W+1) x (H+1)` lattice.
private func lattice(_ board: Board) -> [Point] {
    (0 ... board.height).flatMap { y in (0 ... board.width).map { x in Point(x: x, y: y) } }
}

/// Every border edge, each once: as its left or top end and the step `right` or `down` from there.
private func borderEdges(_ board: Board) -> Set<Edge> {
    Set(lattice(board).flatMap { point in
        board.borderNeighbours(point)
            .filter { $0.dir == .right || $0.dir == .down }
            .map { Edge(point: point, dir: $0.dir) }
    })
}

/// The unit edges of the four sides of a `columns x rows` board.
private func outerEdges(_ columns: UInt16, _ rows: UInt16) -> Set<Edge> {
    let horizontal = (0 ..< columns).flatMap { x in
        [Point(x: x, y: 0), Point(x: x, y: rows)].map { Edge(point: $0, dir: .right) }
    }
    let vertical = (0 ..< rows).flatMap { y in
        [Point(x: 0, y: y), Point(x: columns, y: y)].map { Edge(point: $0, dir: .down) }
    }
    return Set(horizontal + vertical)
}

private func neighbours(_ board: Board, _ point: Point) -> [Neighbour] {
    board.borderNeighbours(point).map { Neighbour(dir: $0.dir, next: $0.next) }
}

private func assertNoDeadEnds(_ board: Board, file: StaticString = #filePath, line: UInt = #line) {
    for point in lattice(board) where board.isBorder(point) {
        let count = board.borderNeighbours(point).count
        XCTAssert(count >= minBorderNeighbours, "\(point) has \(count)", file: file, line: line)
    }
}

final class BorderTests: XCTestCase {
    func testTheBorderOfAFreshBoardIsItsFourOuterEdges() {
        XCTAssertEqual(borderEdges(board()), outerEdges(width, height))
        let full = Board(width: Tuning.boardW, height: Tuning.boardH)
        XCTAssertEqual(borderEdges(full), outerEdges(Tuning.boardW, Tuning.boardH))
    }

    func testTheBorderPointsOfAFreshBoardAreOnItsSides() {
        let board = board()
        for point in lattice(board) {
            let onSide = point.x == 0 || point.x == width || point.y == 0 || point.y == height
            XCTAssertEqual(board.isBorder(point), onSide, "\(point)")
        }
    }

    func testEveryBorderPointOfAFreshBoardHasTwoBorderNeighbours() {
        for fresh in [board(), Board(width: Tuning.boardW, height: Tuning.boardH)] {
            for point in lattice(fresh) where fresh.isBorder(point) {
                XCTAssertEqual(fresh.borderNeighbours(point).count, sideNeighbours, "\(point)")
            }
        }
    }

    func testACornerOfTheBoardLeadsAlongBothSides() {
        let board = board()
        XCTAssertEqual(
            neighbours(board, Point(x: 0, y: 0)),
            [Neighbour(dir: .down, next: Point(x: 0, y: 1)), Neighbour(dir: .right, next: Point(x: 1, y: 0))]
        )
        XCTAssertEqual(
            neighbours(board, Point(x: width, y: height)),
            [
                Neighbour(dir: .up, next: Point(x: width, y: height - 1)),
                Neighbour(dir: .left, next: Point(x: width - 1, y: height)),
            ]
        )
    }

    func testEachNeighbourIsOneStepInItsDirection() {
        var board = board()
        board.setCell(x: 1, y: 1, to: fast)
        for point in lattice(board) {
            for (dir, next) in board.borderNeighbours(point) {
                XCTAssertEqual(dir.step(point), next, "\(point) \(dir)")
            }
        }
    }

    func testBorderEdgesLeadBothWays() {
        var board = board()
        board.setCell(x: 1, y: 1, to: fast)
        board.setCell(x: 2, y: 2, to: slow)
        for point in lattice(board) {
            for (dir, next) in board.borderNeighbours(point) {
                let back = Neighbour(dir: dir.opposite, next: point)
                XCTAssert(neighbours(board, next).contains(back), "\(point) \(dir)")
            }
        }
    }

    func testAClaimedInnerCellAddsItsFourEdgesToTheBorder() {
        var board = board()
        board.setCell(x: 1, y: 1, to: slow)
        var expected = outerEdges(width, height)
        expected.formUnion([
            Edge(point: Point(x: 1, y: 1), dir: .right),
            Edge(point: Point(x: 1, y: 2), dir: .right),
            Edge(point: Point(x: 1, y: 1), dir: .down),
            Edge(point: Point(x: 2, y: 1), dir: .down),
        ])
        XCTAssertEqual(borderEdges(board), expected)
        assertNoDeadEnds(board)
    }

    func testClaimingAlongASideMovesTheBorderInwards() {
        var board = board()
        for x in 0 ..< width {
            board.setCell(x: x, y: 0, to: fast)
        }
        let expected = Set(outerEdges(width, height - 1).map { edge in
            Edge(point: Point(x: edge.point.x, y: edge.point.y + 1), dir: edge.dir)
        })
        XCTAssertEqual(borderEdges(board), expected)
        XCTAssertFalse(board.isBorder(Point(x: 1, y: 0)))
        XCTAssertFalse(board.isBorder(Point(x: 0, y: 0)))
        assertNoDeadEnds(board)
    }

    func testDiagonalClaimedCellsMeetAtAFourWayPoint() {
        var board = board()
        board.setCell(x: 0, y: 0, to: fast)
        board.setCell(x: 1, y: 1, to: fast)
        let point = Point(x: 1, y: 1)
        XCTAssert(board.isBorder(point))
        XCTAssertEqual(board.borderNeighbours(point).map(\.dir), Dir.all)
    }

    func testAFullyClaimedBoardHasNoBorder() {
        var board = board()
        for y in 0 ..< height {
            for x in 0 ..< width {
                board.setCell(x: x, y: y, to: fast)
            }
        }
        XCTAssert(lattice(board).allSatisfy { !board.isBorder($0) })
        XCTAssert(borderEdges(board).isEmpty)
    }

    func testPointsBeyondTheLatticeAreNotOnTheBorder() {
        let board = board()
        let beyond = [Point(x: width + 1, y: 0), Point(x: 0, y: height + 1), Point(x: .max, y: .max)]
        for point in beyond {
            XCTAssertFalse(board.isBorder(point), "\(point)")
            XCTAssert(neighbours(board, point).isEmpty, "\(point)")
        }
    }

    func testEdgesInsideAFreshBoardAreFree() {
        let board = board()
        let inner = Point(x: 1, y: 1)

        for dir in Dir.all {
            XCTAssert(board.isFreeEdge(inner, dir), "\(dir)")
        }
    }

    func testBorderEdgesAndEdgesOffTheLatticeAreNotFree() {
        let board = board()
        let bottom = Point(x: width / 2, y: height)

        XCTAssert(board.isFreeEdge(bottom, .up))
        for dir in [Dir.down, .left, .right] {
            XCTAssertFalse(board.isFreeEdge(bottom, dir), "\(dir)")
        }
    }

    func testAnEdgeBetweenClaimedCellsIsNotFree() {
        var board = board()
        board.setCell(x: 0, y: 0, to: fast)
        board.setCell(x: 0, y: 1, to: slow)

        XCTAssertFalse(board.isFreeEdge(Point(x: 1, y: 1), .left))
        XCTAssert(board.isFreeEdge(Point(x: 1, y: 1), .right))
        XCTAssertFalse(board.isBorderEdge(Point(x: 1, y: 1), .left))
        XCTAssertFalse(neighbours(board, Point(x: 1, y: 1)).contains { $0.dir == .left })
    }

    func testIsBorderEdgeAgreesWithTheBorderNeighbours() {
        var board = board()
        board.setCell(x: 0, y: 0, to: fast)
        board.setCell(x: 2, y: 1, to: slow)
        // One row and column beyond the bottom and right of the lattice, to cover edges leaving
        // it there; the coordinates are unsigned, so the top and left have no beyond.
        for y in 0 ... height + 1 {
            for x in 0 ... width + 1 {
                let point = Point(x: x, y: y)
                for dir in Dir.all {
                    let listed = neighbours(board, point).contains { $0.dir == dir }
                    XCTAssertEqual(board.isBorderEdge(point, dir), listed, "\(point) \(dir)")
                }
            }
        }
    }
}
