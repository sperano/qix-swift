import XCTest
@testable import QixKit

/// Seed of every game the tests play.
let gameSeed: UInt64 = 1_194

/// Dimensions of the small board the lap and corner tests use.
let smallWidth: UInt16 = 4
let smallHeight: UInt16 = 3

/// Dimensions of the board of `testReachingTheBorderClosesTheStix`, tall enough to pen its Qix in
/// `penColumn`.
private let penWidth: UInt16 = 8
private let penHeight: UInt16 = 6

/// The column `penned` keeps the Qix of `testReachingTheBorderClosesTheStix` in, clear of the
/// stix.
private let penColumn: UInt16 = 1

/// Steps the marker-timing tests hold a direction for.
private let steps: UInt32 = 5

/// Lattice steps that take the marker past any edge of the full board.
private let beyondAnyEdge = UInt32(Tuning.boardW) + 1

/// A new full-size game.
func newGame() -> Game {
    Game(rng: Rng(seed: gameSeed))
}

/// A game on `board` with a short Qix in its top-left cell, which must be free.
private func smallGame(_ board: Board) -> Game {
    Game(board: board, qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: gameSeed))
}

/// A free `width x height` board but for claimed walls beside `column` from the second row to the
/// second last, and a vertical Qix down the middle of the column, too long to turn between its
/// walls: it stays in the column however it moves, yet a claim floods from it into the rest of the
/// board through the first and last rows.
func penned(_ width: UInt16, _ height: UInt16, _ column: UInt16) -> (Board, Qix) {
    var board = Board(width: width, height: height)
    let qix = pen(&board, column)
    return (board, qix)
}

/// Claims the walls of a `penned` column on `board` and returns the Qix it keeps.
func pen(_ board: inout Board, _ column: UInt16) -> Qix {
    let (width, height) = (board.width, board.height)
    for y in 1 ..< height - 1 {
        for x in [column > 0 ? column - 1 : nil, column + 1].compactMap(\.self) where x < width {
            board.setCell(x: x, y: y, to: .claimed(.fast))
        }
    }
    let x = Float(column) + 0.5
    let (top, bottom): (Float, Float) = (0.5, Float(height) - 1.5)
    return Qix(a: Vec2(x: x, y: top), b: Vec2(x: x, y: bottom), vel: Vec2(), spin: 0)
}

/// `dir` held with no draw button.
func holding(_ dir: Dir) -> InputState {
    InputState(dir: dir)
}

/// `dir` held with the draw button of `kind`.
func drawing(_ dir: Dir, _ kind: DrawKind) -> InputState {
    InputState(dir: dir, fast: kind == .fast, slow: kind == .slow)
}

/// The ticks one step of a stix drawn with `kind` takes.
func drawStepTicks(_ kind: DrawKind) -> UInt32 {
    switch kind {
    case .fast: Tuning.markerStepTicks
    case .slow: Tuning.slowStepTicks
    }
}

/// Ticks `game` long enough for `steps` steps of a stix drawn towards `dir` with `kind`.
func draw(_ game: inout Game, _ dir: Dir, _ kind: DrawKind, _ steps: UInt32) {
    hold(&game, drawing(dir, kind), steps * drawStepTicks(kind))
}

/// Ticks `game` `ticks` times with the same input.
func hold(_ game: inout Game, _ input: InputState, _ ticks: UInt32) {
    for _ in 0 ..< ticks {
        game.tick(input)
    }
}

/// Ticks `game` long enough for `steps` marker steps towards `dir`.
func walk(_ game: inout Game, _ dir: Dir, _ steps: UInt32) {
    hold(&game, holding(dir), steps * Tuning.markerStepTicks)
}

/// A cell of the board, as `(x, y)` in `claimedCells`.
private struct Spot: Equatable {
    let x: UInt16
    let y: UInt16

    init(_ cell: (UInt16, UInt16)) {
        (x, y) = cell
    }
}

/// The claimed cells of `board` in reading order.
private func claimedCells(_ board: Board) -> [Spot] {
    (0 ..< board.height)
        .flatMap { y in (0 ..< board.width).map { x in Spot((x, y)) } }
        .filter { board.cell(x: Int32($0.x), y: Int32($0.y)).isClaimed }
}

/// Draws the L-shaped stix on the `smallWidth x smallHeight` board: up one step from the marker's
/// start, then left to the left edge, which closes it and claims the cells below it. Returns the
/// game and the stix's lattice points.
private func closedL() -> (Game, [Point]) {
    var game = smallGame(Board(width: smallWidth, height: smallHeight))
    let start = game.marker.pos
    draw(&game, .up, .fast, 1)
    draw(&game, .left, .fast, UInt32(start.x))
    let cornerY = start.y - 1
    var points = [start]
    points.append(contentsOf: (0 ... start.x).reversed().map { Point(x: $0, y: cornerY) })
    return (game, points)
}

final class GameTests: XCTestCase {
    func testNewGameHasNotTicked() {
        XCTAssertEqual(newGame().ticks, 0)
    }

    func testEachTickAdvancesOneStep() {
        var game = newGame()

        game.tick(holding(.left))
        game.tick(InputState())

        XCTAssertEqual(game.ticks, 2)
    }

    func testNewGameHasAFreeBoardAndTheMarkerAtTheBottomCentre() {
        let game = newGame()

        XCTAssertEqual(game.board, Board(width: Tuning.boardW, height: Tuning.boardH))
        XCTAssertEqual(game.marker.pos, Point(x: Tuning.boardW / 2, y: Tuning.boardH))
        XCTAssertEqual(game.marker.state, .onBorder)
    }

    func testMarkerMovesExactlyOneStepPerMarkerStepTicks() {
        var game = newGame()
        let start = game.marker.pos

        for tick in 1 ... steps * Tuning.markerStepTicks {
            game.tick(holding(.right))
            let moved = UInt16(tick / Tuning.markerStepTicks)
            XCTAssertEqual(game.marker.pos, Point(x: start.x + moved, y: start.y))
        }
    }

    func testMarkerStaysPutWithoutADirection() {
        var game = newGame()
        let start = game.marker.pos

        hold(&game, InputState(), steps * Tuning.markerStepTicks)

        XCTAssertEqual(game.marker.pos, start)
    }

    func testReleasingTheDirectionRestartsTheStepCount() {
        var game = newGame()
        let start = game.marker.pos

        hold(&game, holding(.right), Tuning.markerStepTicks - 1)
        game.tick(InputState())
        hold(&game, holding(.right), Tuning.markerStepTicks - 1)

        XCTAssertEqual(game.marker.pos, start)
    }

    func testMarkerCannotLeaveTheBorderWithoutADrawButton() {
        var game = newGame()
        let ticks = beyondAnyEdge * Tuning.markerStepTicks

        for dir in [Dir.up, .left, .up, .right, .down] {
            for _ in 0 ..< ticks {
                game.tick(holding(dir))
                XCTAssert(game.board.isBorder(game.marker.pos), "\(dir)")
            }
        }
    }

    func testMarkerStopsAtTheEdgeItWalksAlong() {
        var game = newGame()

        walk(&game, .right, beyondAnyEdge)

        XCTAssertEqual(game.marker.pos, Point(x: Tuning.boardW, y: Tuning.boardH))
    }

    func testMarkerFollowsTheBorderWithADrawButtonHeld() {
        var game = newGame()
        let start = game.marker.pos
        let input = InputState(dir: .left, fast: true)

        hold(&game, input, steps * Tuning.markerStepTicks)

        XCTAssertEqual(game.marker.pos, Point(x: start.x - UInt16(steps), y: start.y))
    }

    func testMarkerTurnsEveryOuterCornerOnALap() {
        var game = smallGame(Board(width: smallWidth, height: smallHeight))
        let start = game.marker.pos
        let (wide, high) = (UInt32(smallWidth), UInt32(smallHeight))
        let half = UInt32(smallWidth / 2)
        let lap: [(Dir, UInt32, Point)] = [
            (.right, wide - half, Point(x: smallWidth, y: smallHeight)),
            (.up, high, Point(x: smallWidth, y: 0)),
            (.left, wide, Point(x: 0, y: 0)),
            (.down, high, Point(x: 0, y: smallHeight)),
            (.right, half, start),
        ]

        for (dir, steps, corner) in lap {
            walk(&game, dir, steps)
            XCTAssertEqual(game.marker.pos, corner, "\(dir)")
        }
    }

    func testMarkerTurnsTheCornersAroundAClaimedCell() {
        var board = Board(width: smallWidth, height: smallHeight)
        board.setCell(x: smallWidth - 1, y: smallHeight - 1, to: .claimed(.fast))
        var game = smallGame(board)
        let path: [(Dir, Point)] = [
            (.right, Point(x: smallWidth - 1, y: smallHeight)),
            (.right, Point(x: smallWidth - 1, y: smallHeight)),
            (.up, Point(x: smallWidth - 1, y: smallHeight - 1)),
            (.up, Point(x: smallWidth - 1, y: smallHeight - 1)),
            (.right, Point(x: smallWidth, y: smallHeight - 1)),
            (.up, Point(x: smallWidth, y: smallHeight - 2)),
        ]

        for (dir, pos) in path {
            walk(&game, dir, 1)
            XCTAssertEqual(game.marker.pos, pos, "\(dir)")
        }
    }

    func testADrawButtonAndAMoveIntoFreeSpaceStartAStix() throws {
        var game = smallGame(Board(width: smallWidth, height: smallHeight))
        let start = game.marker.pos

        draw(&game, .up, .fast, 1)

        let head = Point(x: start.x, y: start.y - 1)
        XCTAssertEqual(game.marker.pos, head)
        XCTAssertEqual(game.marker.state, .drawing)
        let stix = try XCTUnwrap(game.stix)
        XCTAssertEqual(stix.points, [start, head])
        XCTAssertEqual(stix.kinds, [.fast])
    }

    func testEachDrawButtonStepsAtItsSpeed() {
        for kind in [DrawKind.fast, .slow] {
            var game = newGame()
            let start = game.marker.pos
            let stepTicks = drawStepTicks(kind)

            for tick in 1 ... steps * stepTicks {
                game.tick(drawing(.up, kind))
                let moved = UInt16(tick / stepTicks)
                XCTAssertEqual(game.marker.pos, Point(x: start.x, y: start.y - moved), "\(kind)")
            }
        }
    }

    func testTheSlowButtonFollowsTheBorderAtMarkerSpeed() {
        var game = newGame()
        let start = game.marker.pos

        hold(&game, drawing(.left, .slow), steps * Tuning.markerStepTicks)

        XCTAssertEqual(game.marker.pos, Point(x: start.x - UInt16(steps), y: start.y))
        XCTAssertEqual(game.marker.state, .onBorder)
    }

    func testReleasingBothDrawButtonsStopsTheMarkerOnTheStix() throws {
        var game = newGame()
        draw(&game, .up, .fast, 1)
        let head = game.marker.pos

        walk(&game, .up, steps)

        XCTAssertEqual(game.marker.pos, head)
        XCTAssertEqual(game.marker.state, .drawing)
        XCTAssertEqual(try XCTUnwrap(game.stix).head, head)
    }

    func testPressingADrawButtonAgainResumesDrawing() throws {
        var game = newGame()
        draw(&game, .up, .fast, 1)
        let head = game.marker.pos
        hold(&game, drawing(.up, .fast), Tuning.markerStepTicks - 1)
        game.tick(holding(.up))

        hold(&game, drawing(.up, .slow), Tuning.slowStepTicks - 1)
        XCTAssertEqual(game.marker.pos, head)
        game.tick(drawing(.up, .slow))

        XCTAssertEqual(game.marker.pos, Point(x: head.x, y: head.y - 1))
        XCTAssertEqual(try XCTUnwrap(game.stix).kinds, [.fast, .slow])
    }

    func testASingleFastSegmentMakesTheClaimFast() throws {
        var game = newGame()

        draw(&game, .up, .slow, 2)
        draw(&game, .left, .fast, 1)
        draw(&game, .up, .slow, 1)

        let stix = try XCTUnwrap(game.stix)
        XCTAssertEqual(stix.kinds, [.slow, .fast, .slow])
        XCTAssertEqual(stix.claimKind(), .fast)
    }

    func testAStixDrawnSlowThroughoutClaimsSlow() throws {
        var game = newGame()

        draw(&game, .up, .slow, 2)
        draw(&game, .right, .slow, 1)

        XCTAssertEqual(try XCTUnwrap(game.stix).claimKind(), .slow)
    }

    func testAnIllegalDrawStepLeavesTheMarkerDrawingWhereItIs() throws {
        var game = newGame()
        draw(&game, .up, .fast, 2)
        let stix = try XCTUnwrap(game.stix)

        draw(&game, .down, .fast, 1)

        XCTAssertEqual(game.marker.pos, stix.head)
        XCTAssertEqual(game.marker.state, .drawing)
        XCTAssertEqual(game.stix, stix)
    }

    func testADrawStepOffTheBoardStartsNoStix() {
        var game = newGame()
        let start = game.marker.pos

        draw(&game, .down, .fast, 1)

        XCTAssertEqual(game.marker.pos, start)
        XCTAssertEqual(game.marker.state, .onBorder)
        XCTAssertNil(game.stix)
    }

    func testReachingTheBorderClosesTheStix() {
        let (board, qix) = penned(penWidth, penHeight, penColumn)
        var game = Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
        let start = game.marker.pos

        draw(&game, .up, .fast, UInt32(penHeight))

        XCTAssertEqual(game.marker.pos, Point(x: start.x, y: 0))
        XCTAssertEqual(game.marker.state, .onBorder)
        XCTAssertNil(game.stix)
        walk(&game, .down, 1)
        XCTAssertEqual(game.marker.pos, Point(x: start.x, y: 1))
    }

    func testTheFormerStixPointsAreAllBorderPoints() {
        let (game, points) = closedL()

        XCTAssertNil(game.stix)
        let (start, corner) = (points[0], points[1])
        let belowL = (corner.y ..< smallHeight).flatMap { y in (0 ..< start.x).map { x in Spot((x, y)) } }
        XCTAssertEqual(claimedCells(game.board), belowL)
        for point in points {
            XCTAssert(game.board.isBorder(point), "\(point)")
        }
    }

    func testTheMarkerEndsOnTheBorderAtTheClosingPoint() throws {
        let (game, points) = closedL()

        XCTAssertEqual(game.marker.pos, try XCTUnwrap(points.last))
        XCTAssertEqual(game.marker.state, .onBorder)
    }

    func testTheMarkerWalksTheNewBorderBackToTheStixStart() {
        let (closed, points) = closedL()
        var game = closed
        let (start, corner) = (points[0], points[1])

        walk(&game, .right, UInt32(corner.x))
        XCTAssertEqual(game.marker.pos, corner)
        walk(&game, .down, 1)

        XCTAssertEqual(game.marker.pos, start)
        XCTAssertEqual(game.marker.state, .onBorder)
    }
}
