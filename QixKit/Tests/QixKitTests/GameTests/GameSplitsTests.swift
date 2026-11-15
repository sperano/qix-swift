import XCTest
@testable import QixKit

// Ending a level by splitting the two Qix apart, and the multiplier it
// raises.

/// The level a split game goes on to.
private let nextLevel: UInt32 = Tuning.firstLevel + 1

/// How far in from a side of the full board `sidesGame` pens a Qix.
private let penColumn: UInt16 = 1

/// The column between `penColumn` and the middle where
/// `testAClaimKeepingBothQixTogetherIsNoSplit` pens its second Qix.
private let secondPenColumn: UInt16 = 3

/// Dimensions of the board of `aSplitClaim`: the stix runs up
/// column `pocketWidth / 2` from the marker's start.
private let pocketWidth: UInt16 = 8
private let pocketHeight: UInt16 = 4

/// The columns `aSplitClaim` claims before the stix: the first walls
/// a Qix into column 0, the others narrow the area of the second Qix.
private let pocketClaimedColumns: [UInt16] = [1, 6, 7]

/// The cells the stix of `aSplitClaim` claims: columns 2 and 3, left
/// of it, with no Qix.
private let pocketStixCells: UInt32 = 2 * UInt32(pocketHeight)

/// The claimed fraction after the stix of `aSplitClaim`: 20 cells of
/// 32, above the lowest threshold.
private let pocketFraction: Float = 0.625

/// A full-size game with no Sparx and a Qix `pen`ned in each of
/// `columns`.
private func twoQixGame(_ columns: [UInt16]) -> Game {
    var board = Board(width: Tuning.boardW, height: Tuning.boardH)
    let qix = columns.map { pen(&board, $0) }
    return Game(board: board, qix: qix, sparx: [], rng: Rng(seed: gameSeed))
}

/// A `twoQixGame` with a Qix near either side, which a stix up the
/// middle splits.
private func sidesGame() -> Game {
    twoQixGame([penColumn, Tuning.boardW - 1 - penColumn])
}

/// Whether `event` is `Event.death`.
private func isDeath(_ event: Event) -> Bool {
    if case .death = event {
        return true
    }
    return false
}

/// Whether `event` is `Event.levelComplete`.
private func isLevelComplete(_ event: Event) -> Bool {
    if case .levelComplete = event {
        return true
    }
    return false
}

/// Draws the stix up the middle of the full board, from the marker's start
/// to the top edge, and checks that it closed without a death.
private func closeUpTheMiddle(_ game: inout Game) {
    let input = drawing(.up, .fast)
    for _ in 0 ..< UInt32(Tuning.boardH) * drawStepTicks(.fast) {
        game.tick(input)
        let died = game.events.contains(where: isDeath)
        XCTAssertFalse(died, "the stix was hit")
    }
    XCTAssertNil(game.stix, "the stix did not close")
}

/// A `pocketWidth x pocketHeight` game at the lowest threshold whose stix up the
/// middle claims `pocketStixCells` and leaves a Qix in column 0, walled
/// off by claimed column 1, and another in column 5, right of the stix.
private func aSplitClaim() -> Game {
    var board = Board(width: pocketWidth, height: pocketHeight)
    for x in pocketClaimedColumns {
        for y in 0 ..< pocketHeight {
            board.setCell(x: x, y: y, to: .claimed(.fast))
        }
    }
    let cells: [(UInt16, UInt16)] = [(0, 0), (5, 0)]
    let qix = cells.map(qixAt)
    var game = Game(board: board, qix: qix, sparx: [], rng: Rng(seed: gameSeed))
    game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))
    draw(&game, .up, .fast, UInt32(pocketHeight))
    XCTAssertNil(game.stix, "the stix did not close")
    return game
}

final class GameSplitsTests: XCTestCase {
    func testAStixSplittingTheQixEndsTheLevel() {
        var game = sidesGame()
        let board = game.board

        closeUpTheMiddle(&game)

        XCTAssert(game.isLevelComplete)
        XCTAssertEqual(game.board, board, "the stix claimed cells")
        XCTAssertEqual(
            game.events,
            [
                .draw(.fast),
                .levelComplete(fraction: game.board.claimedFraction(), bonus: 0, split: true),
            ]
        )
        XCTAssertEqual(game.score.points, 0, "nothing claimed, no bonus")
    }

    func testASplitLevelNoLongerTicks() {
        var game = sidesGame()
        closeUpTheMiddle(&game)
        let ticks = game.ticks

        game.tick(holding(.left))

        XCTAssertEqual(game.ticks, ticks)
        XCTAssertEqual(game.events, [])
    }

    func testASplitRaisesTheMultiplierByOne() {
        var game = sidesGame()
        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier)

        closeUpTheMiddle(&game)

        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier + 1)
    }

    func testASplitRaisesARaisedMultiplierByOne() {
        var game = sidesGame()
        game.setMultiplier(Tuning.startingMultiplier + 1)

        closeUpTheMiddle(&game)

        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier + 2)
    }

    func testAClaimKeepingBothQixTogetherIsNoSplit() {
        var game = twoQixGame([penColumn, secondPenColumn])

        closeUpTheMiddle(&game)

        XCTAssertGreaterThan(game.board.claimedFraction(), 0.0, "nothing claimed")
        XCTAssertFalse(game.isLevelComplete)
        let ended = game.events.contains(where: isLevelComplete)
        XCTAssertFalse(ended, "\(game.events)")
        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier)
    }

    func testASplitClaimScoresAtTheOldMultiplierWithoutABonus() {
        let game = aSplitClaim()

        XCTAssertEqual(game.board.claimedFraction(), pocketFraction)
        XCTAssertEqual(
            game.events,
            [
                .draw(.fast),
                .claim(cells: Int(pocketStixCells), kind: .fast),
                .levelComplete(fraction: pocketFraction, bonus: 0, split: true),
            ]
        )
        let claimPoints = pocketStixCells * Tuning.pointsPerCell * Tuning.startingMultiplier
        XCTAssertEqual(game.score.points, claimPoints, "a bonus on a split")
        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier + 1)
    }

    func testTheRaisedMultiplierScoresTheNextLevel() {
        var game = sidesGame()
        closeUpTheMiddle(&game)

        game.startLevel(nextLevel)
        for dir in [Dir.up, .left, .down] {
            draw(&game, dir, .fast, 1)
        }

        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier + 1)
        let points = Tuning.pointsPerCell * (Tuning.startingMultiplier + 1)
        XCTAssertEqual(game.score.points, points, "one cell claimed")
    }

    func testASplitAtTheHighestMultiplierKeepsIt() {
        var game = sidesGame()
        game.setMultiplier(Tuning.maxMultiplier)

        closeUpTheMiddle(&game)

        XCTAssert(game.isLevelComplete)
        XCTAssertEqual(game.multiplier, Tuning.maxMultiplier)
    }

    func testTheMultiplierIsSetWithinItsRange() {
        var game = sidesGame()

        game.setMultiplier(Tuning.maxMultiplier + 1)
        XCTAssertEqual(game.multiplier, Tuning.maxMultiplier)
        game.setMultiplier(Tuning.startingMultiplier - 1)
        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier)
    }
}
