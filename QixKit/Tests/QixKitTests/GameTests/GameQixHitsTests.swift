import XCTest
@testable import QixKit

// The Qix killing the player through `Game.tick`.

/// Dimensions of the boards: the marker starts at `(width / 2, height)`.
private let width: UInt16 = 20
private let height: UInt16 = 30

/// Rows of free cells along the bottom edge of `bandAndColumn`.
private let bandRows: UInt16 = 3

/// The free column of `bandAndColumn`, right of the marker's start.
let column: UInt16 = 15

/// Steps the stix goes up into the band before turning right.
let stepsUp: UInt32 = 2

/// Steps the marker goes past `column`, far enough that the Qix in it
/// stays clear of the marker's square.
private let clearOfColumn: UInt32 = 3

/// Where the top of `fallingQix`'s Qix starts, its length and the
/// speed it starts falling at, in playfield units (per tick).
private let fallTop: Float = 10.0
private let fallLength: Float = 2.0
private let fallSpeed: Float = 0.5

/// A free column at the top of the board, closed off from the rest of
/// it: `withAPennedQix`'s other Qix is kept there, clear of every
/// stix.
private let pocketColumn: UInt16 = 2
private let pocketRows: UInt16 = 10

/// Ticks the tests watch a standing marker or Qix for.
private let watchTicks: UInt32 = 60

/// The free cells of `closingThroughAQix`: a box under a channel one
/// row high and two cells wide, which the stix up the box's middle
/// reaches the border in.
private let closingBox: (Range<UInt16>, Range<UInt16>) = (width / 2 - 2 ..< width / 2 + 2, height - 2 ..< height)
private let closingChannel: (Range<UInt16>, UInt16) = (width / 2 - 1 ..< width / 2 + 1, height - 3)

/// Steps of the stix up from the marker's start to the channel.
private let closingSteps: UInt32 = 3

/// How far the ends of `closingThroughAQix`'s Qix are from the sides
/// of the channel, and how far down into it the Qix lies: too little room
/// to move at its slowest speed, and clear of the square of the marker
/// below the channel.
private let channelMargin: Float = 0.1
private let channelDepth: Float = 0.25

/// The free cells of `passingTheClosingLine`: a corridor one row
/// high, above a column two cells wide down to the marker's start, which
/// the stix up the column's middle reaches the corridor's top edge in.
private let corridor: (Range<UInt16>, UInt16) = (2 ..< width - 2, height - 4)
private let corridorColumn: Range<UInt16> = width / 2 - 1 ..< width / 2 + 1

/// Steps of the stix up from the marker's start to the corridor's top
/// edge.
private let corridorSteps: UInt32 = 4

/// Where the midpoint of `passingTheClosingLine`'s Qix starts, its
/// length and the speed it starts at to the right: a Qix shorter than it
/// moves in a tick, high enough in the corridor to stay clear of the
/// marker's square.
private let passingStart: (Float, Float) = (passingX, 0.2)
private let passingX: Float = 5.25
private let passingLength: Float = 0.4
private let passingSpeed: Float = 0.8

/// A `width x height` board with only the cells `free` keeps free.
private func boardWith(_ free: (UInt16, UInt16) -> Bool) -> Board {
    var board = Board(width: width, height: height)
    for y in 0 ..< height {
        for x in 0 ..< width where !free(x, y) {
            board.setCell(x: x, y: y, to: .claimed(.fast))
        }
    }
    return board
}

/// A vertical Qix `length` long, down from `(x, top)`: on a free column
/// almost as long, the claimed cells around it keep it there while it
/// ticks.
private func columnQix(_ x: Float, _ top: Float, _ length: Float) -> Qix {
    let (topEnd, bottomEnd) = (Vec2(x: x, y: top), Vec2(x: x, y: top + length))
    return Qix(a: topEnd, b: bottomEnd, vel: Vec2(), spin: 0.0)
}

/// A band of free rows along the bottom edge and a free column from it up
/// to the top edge, with a Qix along the column that crosses every row of
/// the band.
func bandAndColumn() -> Game {
    bandAndColumnWith([])
}

/// `bandAndColumn` with `sparx`.
func bandAndColumnWith(_ sparx: [Sparx]) -> Game {
    let board = boardWith { x, y in y >= height - bandRows || x == column }
    let qix = columnQix(Float(column) + 0.5, 0.5, Float(height) - 1.0)
    return Game(board: board, qix: [qix], sparx: sparx, rng: Rng(seed: gameSeed))
}

/// `bandAndColumn` with another Qix in a pocket of its own, either
/// before the column's Qix in the game's list or after it.
private func withAPennedQix(_ pennedFirst: Bool) -> Game {
    let pocket = { (x: UInt16, y: UInt16) in x == pocketColumn && y < pocketRows }
    let board = boardWith { x, y in y >= height - bandRows || x == column || pocket(x, y) }
    let length = Float(pocketRows) - 1.0
    let penned = columnQix(Float(pocketColumn) + 0.5, 0.5, length)
    let inColumn = columnQix(Float(column) + 0.5, 0.5, Float(height) - 1.0)
    let qix = pennedFirst ? [penned, inColumn] : [inColumn, penned]
    return Game(board: board, qix: qix, sparx: [], rng: Rng(seed: gameSeed))
}

/// A box of free cells around the bottom of the marker's column, under a
/// channel of two free cells either side of it, holding a level Qix that
/// fills the channel: it cannot move, and the stix up the column closes
/// with a step across it.
private func closingThroughAQix() -> Game {
    let ((boxX, boxY), (channelX, channelY)) = (closingBox, closingChannel)
    let inBox = { (x: UInt16, y: UInt16) in boxX.contains(x) && boxY.contains(y) }
    let board = boardWith { x, y in inBox(x, y) || (channelX.contains(x) && y == channelY) }
    let y = Float(channelY) + channelDepth
    let left = Vec2(x: Float(channelX.lowerBound) + channelMargin, y: y)
    let right = Vec2(x: Float(channelX.upperBound) - channelMargin, y: y)
    let qix = Qix(a: left, b: right, vel: Vec2(), spin: 0.0)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// A corridor across the board, over a column down to the marker's
/// start, with a short level Qix in the corridor heading right: it
/// crosses the marker's column in the tick before the stix up that column
/// reaches the corridor's top edge.
private func passingTheClosingLine() -> Game {
    let ((corridorX, corridorY), columnX) = (corridor, corridorColumn)
    let board = boardWith { x, y in
        (corridorX.contains(x) && y == corridorY) || (columnX.contains(x) && y > corridorY)
    }
    let mid = Vec2(x: passingStart.0, y: Float(corridorY) + passingStart.1)
    let half = Vec2(x: passingLength * 0.5, y: 0.0)
    let qix = Qix(a: mid - half, b: mid + half, vel: Vec2(x: passingSpeed, y: 0.0), spin: 0.0)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// Ticks `game` `ticks` times with `input` and returns the deaths the
/// Qix raised: a marker standing still that long also lights the fuse.
private func deaths(_ game: inout Game, _ input: InputState, _ ticks: UInt32) -> [Event] {
    var deaths: [Event] = []
    for _ in 0 ..< ticks {
        game.tick(input)
        deaths.append(contentsOf: game.events.filter { $0 == .death(.qix) })
    }
    return deaths
}

/// `bandAndColumn` with a short Qix high up the column instead,
/// falling towards the band: it reaches the band only after a stix drawn
/// across the column has passed it.
private func fallingQix() -> Game {
    let board = boardWith { x, y in y >= height - bandRows || x == column }
    let qix = Qix(
        a: Vec2(x: Float(column) + 0.5, y: fallTop),
        b: Vec2(x: Float(column) + 0.5, y: fallTop + fallLength),
        vel: Vec2(x: 0.0, y: fallSpeed),
        spin: 0.0
    )
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// Draws a stix up into the band, then `right` steps to the right, and
/// returns the deaths raised on the way.
private func drawUpThenRight(_ game: inout Game, _ right: UInt32) -> [Event] {
    let kind = DrawKind.fast
    var raised = deaths(&game, drawing(.up, kind), stepsUp * Tuning.markerStepTicks)
    raised.append(contentsOf: deaths(&game, drawing(.right, kind), right * Tuning.markerStepTicks))
    return raised
}

/// Whether `event` is `Event.claim`.
private func isClaim(_ event: Event) -> Bool {
    if case .claim = event {
        return true
    }
    return false
}

final class GameQixHitsTests: XCTestCase {
    func testAQixCrossingAHorizontalStixKills() {
        var game = fallingQix()
        let startX = UInt32(game.marker.pos.x)
        let pastColumn = UInt32(column) + clearOfColumn - startX
        var raised = drawUpThenRight(&game, pastColumn)
        XCTAssertEqual(raised, [], "the Qix reached the stix before the marker passed")
        let head = game.marker.pos

        var ticks: UInt32 = 0
        while raised.isEmpty, ticks < watchTicks {
            raised = deaths(&game, InputState(), 1)
            ticks += 1
        }

        XCTAssertEqual(raised, [.death(.qix)])
        XCTAssertEqual(UInt32(head.x), UInt32(column) + clearOfColumn)
        XCTAssertFalse(qixHitsMarker(game.qix[0], head), "the Qix touches the marker")
    }

    func testAQixBesideTheStixDoesNotKill() {
        var game = bandAndColumn()
        let startX = UInt32(game.marker.pos.x)
        let shortOfColumn = UInt32(column) - 1 - startX

        var raised = drawUpThenRight(&game, shortOfColumn)
        XCTAssertNotNil(game.stix, "the stix closed")
        XCTAssertEqual(game.marker.pos.x, column - 1)
        // The fuse may kill the standing marker meanwhile: `deaths` only
        // counts the Qix's.
        raised.append(contentsOf: deaths(&game, InputState(), watchTicks))

        XCTAssertEqual(raised, [])
    }

    func testAQixNextToAMarkerOnTheBorderDoesNotKill() {
        let column = width / 2
        let board = boardWith { x, _ in x == column }
        let length = Float(height) - 0.5
        let qix = columnQix(Float(column) + 0.25, 0.25, length)
        var game = Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
        var touchingTicks: UInt32 = 0

        for _ in 0 ..< watchTicks {
            game.tick(InputState())
            XCTAssertEqual(game.events, [])
            touchingTicks += qixHitsMarker(game.qix[0], game.marker.pos) ? 1 : 0
        }

        XCTAssertGreaterThan(touchingTicks, 0, "the Qix never came near the marker")
    }

    func testEitherOfTwoQixKills() {
        for pennedFirst in [true, false] {
            var game = withAPennedQix(pennedFirst)
            let startX = UInt32(game.marker.pos.x)
            let pastColumn = UInt32(column) + 1 - startX

            let raised = drawUpThenRight(&game, pastColumn)

            XCTAssertEqual(raised, [.death(.qix)], "\(pennedFirst)")
            let penned = game.qix[pennedFirst ? 0 : 1]
            XCTAssertLessThan(penned.a.y, Float(pocketRows), "\(penned) left")
        }
    }

    func testAStixClosingAcrossAQixKillsInsteadOfClaiming() {
        var game = closingThroughAQix()
        let (board, start) = (game.board, game.marker)
        let up = drawing(.up, .fast)
        let beforeClose = (closingSteps - 1) * Tuning.markerStepTicks
        XCTAssertEqual(deaths(&game, up, beforeClose), [])
        let head = Point(x: width / 2, y: height - (UInt16(closingSteps) - 1))
        XCTAssertEqual(game.stix?.head, head)

        let raised = deaths(&game, up, Tuning.markerStepTicks)

        XCTAssertEqual(raised, [.death(.qix)])
        XCTAssertEqual(game.board, board, "the stix claimed cells")
        XCTAssertEqual(game.marker, start)
        XCTAssertNil(game.stix)
        XCTAssertEqual(game.qix[0].a.y, Float(closingChannel.1) + channelDepth)
    }

    func testAQixPastTheClosingLineDoesNotStopTheClaim() {
        var game = passingTheClosingLine()
        let board = game.board
        let up = drawing(.up, .fast)
        let beforeClose = corridorSteps * Tuning.markerStepTicks - 1
        XCTAssertEqual(deaths(&game, up, beforeClose), [])
        let (corridorX, corridorY) = corridor
        let top = Point(x: width / 2, y: corridorY)
        var closing = Stix(start: Point(x: top.x, y: top.y + 1))
        closing.push(top, .fast)
        let qix = game.qix[0]
        let now = (qix.a, qix.b)
        XCTAssert(
            sweepHitsStix(qix.previous, now, closing),
            "the Qix did not cross the closing line in the last tick"
        )
        XCTAssertFalse(sweepHitsStix(now, now, closing), "the Qix is on it")

        let raised = deaths(&game, up, 1)

        XCTAssertEqual(raised, [])
        XCTAssertNil(game.stix)
        XCTAssert(game.events.contains(where: isClaim), "the stix claimed nothing")
        XCTAssert(game.board.cell(x: Int32(corridorX.lowerBound), y: Int32(corridorY)).isClaimed)
        XCTAssertNotEqual(game.board, board)
    }
}
