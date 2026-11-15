import XCTest
@testable import QixKit

/// Dimensions of the board: the stix runs up column `width / 2` from the marker's start, leaving
/// the Qix in cell `(0, 0)` on its left.
private let width: UInt16 = 8
private let height: UInt16 = 3

/// Cells left of the stix claimed before it, in rows `1 ..< height`, from column 0 on: clear of the
/// stix's column, so its points stay off the border, and of the top row, which keeps the Qix's area
/// in one piece.
private let claimedBefore: [(UInt16, UInt16)] = [(0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2)]

/// The cells right of the stix, which closing it claims.
private let stixClaimCells = UInt32(width / 2) * UInt32(height)

/// The events of the step closing the stix before any end of the level: the step itself and its
/// claim.
private let closingEvents: [Event] = [
    .draw(.fast),
    .claim(cells: Int(stixClaimCells), kind: .fast),
]

/// The board's claimed fraction after the stix with every cell of `claimedBefore` claimed: 18
/// cells of 24.
private let fractionAfter: Float = 0.75

/// A threshold below `fractionAfter`, and the whole percent points between them.
private let lowThreshold: Float = 0.5
private let percentAboveLow: UInt32 = 25

/// Height of the board of `testTheCompletingClaimPutsTheFuseOut`: tall enough for `penned` to keep
/// its Qix in the left column, out of reach of the stix while the fuse lights. Closing the stix
/// claims more than the lowest threshold of it.
private let fuseHeight: UInt16 = 6

/// Where the Sparx of `gameWithSparx` starts: on the top edge, left of the stix, on a border the
/// claim keeps.
private let sparxStart = Point(x: 1, y: 0)

/// The events of a step closing the stix and completing the level at `fractionAfter` with `bonus`.
private func completingEvents(bonus: UInt32 = 0) -> [Event] {
    closingEvents + [.levelComplete(fraction: fractionAfter, bonus: bonus, split: false)]
}

/// A game on the `width x height` board with the first `claimed` cells of `claimedBefore`
/// claimed, the Qix in cell `(0, 0)` and `sparx`.
private func gameWith(_ claimed: Int, _ sparx: [Sparx]) -> Game {
    var board = Board(width: width, height: height)
    for (x, y) in claimedBefore[..<claimed] {
        board.setCell(x: x, y: y, to: .claimed(.fast))
    }
    return Game(board: board, qix: [qixAt((0, 0))], sparx: sparx, rng: Rng(seed: gameSeed))
}

/// A `gameWith` no Sparx.
private func gameWithClaimed(_ claimed: Int) -> Game {
    gameWith(claimed, [])
}

/// A `gameWith` every cell of `claimedBefore` claimed and a Sparx at `sparxStart` heading right
/// along the top edge.
private func gameWithSparx() -> Game {
    let sparx = Sparx(pos: sparxStart, dir: .right, kind: .normal)
    return gameWith(claimedBefore.count, [sparx])
}

/// Draws the stix up from the marker's start to the top edge.
private func closeStix(_ game: inout Game) {
    draw(&game, .up, .fast, UInt32(height))
    XCTAssertNil(game.stix, "the stix did not close")
}

/// Completing a level through `Game.tick`: a claim reaching the claim threshold, which leaves the
/// multiplier as it is.
final class GameLevelsTests: XCTestCase {
    func testANewGameHasTheDefaultThreshold() {
        let game = gameWithClaimed(0)

        XCTAssertEqual(game.claimThreshold, ClaimThreshold())
        XCTAssertFalse(game.isLevelComplete)
    }

    func testAClaimExactlyAtTheThresholdCompletesTheLevel() {
        var game = gameWithClaimed(claimedBefore.count)
        XCTAssertEqual(Tuning.claimThresholdDefault, fractionAfter)

        closeStix(&game)

        XCTAssertEqual(game.board.claimedFraction(), fractionAfter)
        XCTAssert(game.isLevelComplete)
        XCTAssertEqual(game.events, completingEvents())
        let claimPoints = stixClaimCells * Tuning.pointsPerCell
        XCTAssertEqual(game.score.points, claimPoints, "a bonus at the threshold")
    }

    func testAThresholdCompletionKeepsTheMultiplier() {
        var game = gameWithClaimed(claimedBefore.count)
        game.setMultiplier(Tuning.startingMultiplier + 1)

        closeStix(&game)

        XCTAssertEqual(game.events, completingEvents())
        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier + 1)
    }

    func testAClaimBelowTheThresholdDoesNotCompleteTheLevel() {
        var game = gameWithClaimed(claimedBefore.count - 1)

        closeStix(&game)

        XCTAssert(game.board.claimedFraction() < Tuning.claimThresholdDefault)
        XCTAssertFalse(game.isLevelComplete)
        XCTAssertEqual(game.events, closingEvents)
        let ticks = game.ticks
        game.tick(holding(.left))
        XCTAssertEqual(game.ticks, ticks + 1, "the game stopped ticking")
    }

    func testTheBonusScoresEachWholePercentAboveTheThreshold() {
        var game = gameWithClaimed(claimedBefore.count)
        game.setClaimThreshold(ClaimThreshold(lowThreshold))

        closeStix(&game)

        XCTAssert(game.isLevelComplete)
        let claimPoints = stixClaimCells * Tuning.pointsPerCell
        let bonus = percentAboveLow * Tuning.bonusPerPercent
        XCTAssertEqual(game.score.points, claimPoints + bonus)
        XCTAssertEqual(game.events, completingEvents(bonus: bonus))
    }

    func testACompletedLevelNoLongerTicks() {
        var game = gameWithClaimed(claimedBefore.count)
        closeStix(&game)
        let (ticks, marker, score) = (game.ticks, game.marker, game.score)

        hold(&game, holding(.left), UInt32(width))

        XCTAssertEqual(game.ticks, ticks)
        XCTAssertEqual(game.marker, marker)
        XCTAssertEqual(game.score, score)
        XCTAssertEqual(game.events, [])
    }

    func testTheCompletingClaimPutsTheFuseOut() {
        let (board, qix) = penned(width, fuseHeight, 0)
        var game = Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
        game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))
        draw(&game, .up, .fast, UInt32(fuseHeight) - 1)
        hold(&game, InputState(), Tuning.fuseDelayTicks)
        XCTAssertNotNil(game.fuse, "the fuse did not light")

        draw(&game, .up, .fast, 1)

        XCTAssert(game.isLevelComplete)
        XCTAssertNil(game.stix)
        XCTAssertNil(game.fuse)
    }

    func testNothingMovesAfterTheCompletingClaimInItsTick() {
        var game = gameWithSparx()
        var below = gameWithSparx()
        below.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.upperBound))
        let input = drawing(.up, .fast)
        let ticks = UInt32(height) * Tuning.markerStepTicks
        hold(&game, input, ticks - 1)
        hold(&below, input, ticks - 1)
        XCTAssertFalse(game.isLevelComplete, "the level completed early")
        let last = (qix: game.qix, sparx: game.sparx)

        game.tick(input)
        below.tick(input)

        XCTAssert(game.isLevelComplete)
        XCTAssertFalse(below.isLevelComplete)
        XCTAssertEqual(game.events, completingEvents())
        XCTAssertEqual(game.qix, last.qix)
        XCTAssertEqual(game.sparx, last.sparx)
        XCTAssertNotEqual(below.qix, last.qix, "the Qix stands still below the threshold")
        XCTAssertNotEqual(below.sparx, last.sparx, "the Sparx stands still below the threshold")
    }
}
