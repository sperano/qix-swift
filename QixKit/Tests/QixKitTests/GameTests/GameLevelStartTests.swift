import XCTest
@testable import QixKit

/// Levels the set-up tests start: the first, the first with two Qix and the end of the difficulty
/// ramp.
private let levels: [UInt32] = [
    Tuning.firstLevel,
    Tuning.twoQixFromLevel,
    Tuning.firstLevel + Tuning.difficultyRampLevels,
]

/// The level `aPlayedGame` goes on to.
private let nextLevel: UInt32 = Tuning.firstLevel + 1

/// The claim threshold and the starting lives of `rules`.
private let rulesThreshold: Float = 0.6
private let rulesLives: UInt32 = 5

/// Rounding slack on where the Qix start.
private let epsilon: Float = 1e-4

/// Ticks the two-Qix game runs to see both Qix move.
private let runTicks: UInt32 = 10

/// Where the Qix of `assertQixCentredAt` sit on the board's height: the middle row.
private let middleRow: Float = 0.5

/// The fractions of the board's width the Qix start at: the centre for one, the thirds for two.
private let centreX: Float = 0.5
private let oneThird: Float = 1.0 / 3.0
private let twoThirds: Float = 2.0 / 3.0

/// `game` is set up as `LevelConfig.forLevel` says for `level`.
private func assertSetUpFor(_ game: Game, _ level: UInt32, line: UInt = #line) {
    let config = LevelConfig.forLevel(level)
    XCTAssertEqual(game.level, level, line: line)
    XCTAssertEqual(game.qix.count, config.qixCount, "level \(level)", line: line)
    for qix in game.qix {
        XCTAssertEqual(qix.speed, config.qixSpeed, "level \(level)", line: line)
    }
    let sparx = Sparx.spawnLevel(game.board, config.sparxCount)
    XCTAssertEqual(game.sparx, sparx, "level \(level)", line: line)
    XCTAssertEqual(game.sparxMeter, SparxMeter(length: config.meterTicks), "level \(level)", line: line)
}

/// A full-size game with its Qix in the top-left cell and no Sparx that lost a life to the fuse,
/// then claimed the cell left of the marker's start with a fast stix.
private func aPlayedGame() -> Game {
    let board = Board(width: Tuning.boardW, height: Tuning.boardH)
    var game = Game(board: board, qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: gameSeed))
    dieByFuse(&game)
    stand(&game, game.graceTicks)
    for dir in [Dir.up, .left, .down] {
        draw(&game, dir, .fast, 1)
    }
    XCTAssertEqual(game.score.points, Tuning.pointsPerCell, "nothing claimed")
    return game
}

/// A full-size game with its Qix in the top-left cell, no Sparx and the lowest claim threshold,
/// which a stix up the middle completes by claiming the right half.
private func aCompletedLevel() -> Game {
    let board = Board(width: Tuning.boardW, height: Tuning.boardH)
    var game = Game(board: board, qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: gameSeed))
    game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))
    draw(&game, .up, .fast, UInt32(Tuning.boardH))
    XCTAssert(game.isLevelComplete, "the level did not complete")
    return game
}

/// The Qix of `game` are centred at `xs`, as fractions of the board's width, in order, on its
/// middle row.
private func assertQixCentredAt(_ game: Game, _ xs: [Float], line: UInt = #line) {
    XCTAssertEqual(game.qix.count, xs.count, line: line)
    let (width, height) = (Float(Tuning.boardW), Float(Tuning.boardH))
    for (qix, x) in zip(game.qix, xs) {
        let mid = qix.a.midpoint(qix.b)
        let expected = Vec2(x: width * x, y: height * middleRow)
        XCTAssert((mid - expected).length < epsilon, "\(mid), not \(expected)", line: line)
    }
}

/// Rules other than the default ones.
private func rules() -> Rules {
    let rules = Rules(threshold: ClaimThreshold(rulesThreshold), startingLives: StartingLives(rulesLives))
    XCTAssertNotEqual(rules, Rules())
    return rules
}

/// Starting a level from the level table: `Game.init(rng:)` and `Game.startLevel`.
final class GameLevelStartTests: XCTestCase {
    func testANewGameStartsTheFirstLevel() {
        assertSetUpFor(newGame(), Tuning.firstLevel)
    }

    func testALevelIsSetUpFromItsRowOfTheTable() {
        for level in levels {
            var game = newGame()

            game.startLevel(level)

            assertSetUpFor(game, level)
        }
    }

    func testALevelBelowTheFirstStartsTheFirst() {
        var game = newGame()

        game.startLevel(Tuning.firstLevel - 1)

        assertSetUpFor(game, Tuning.firstLevel)
    }

    func testASingleQixStartsAtTheCentre() {
        assertQixCentredAt(newGame(), [centreX])
    }

    func testTwoQixStartAThirdOfTheWayInFromEitherSide() {
        var game = newGame()

        game.startLevel(Tuning.twoQixFromLevel)

        assertQixCentredAt(game, [oneThird, twoThirds])
    }

    func testBothQixMove() {
        var game = newGame()
        game.startLevel(Tuning.twoQixFromLevel)
        let start = game.qix

        hold(&game, InputState(), runTicks)

        for (qix, start) in zip(game.qix, start) {
            XCTAssertFalse(qix.a == start.a && qix.b == start.b)
        }
    }

    func testStartingALevelKeepsTheScoreAndTheLives() {
        var game = aPlayedGame()
        let (score, lives) = (game.score, game.lives)
        XCTAssert(lives < Tuning.startingLives, "no life lost")

        game.startLevel(nextLevel)

        XCTAssertEqual(game.score, score)
        XCTAssertEqual(game.lives, lives)
    }

    func testStartingALevelFreesTheBoardAndPutsTheMarkerBack() {
        var game = aPlayedGame()
        XCTAssertNotEqual(game.board, Board(width: Tuning.boardW, height: Tuning.boardH))

        game.startLevel(nextLevel)

        XCTAssertEqual(game.board, Board(width: Tuning.boardW, height: Tuning.boardH))
        XCTAssertEqual(game.marker.pos, Point(x: Tuning.boardW / 2, y: Tuning.boardH))
        XCTAssertEqual(game.marker.state, .onBorder)
        assertSetUpFor(game, nextLevel)
    }

    func testStartingALevelDropsTheStix() {
        var game = newGame()
        draw(&game, .up, .fast, 1)
        XCTAssertNotNil(game.stix)

        game.startLevel(nextLevel)

        XCTAssertNil(game.stix)
        XCTAssertNil(game.fuse)
    }

    func testStartingALevelEndsTheGracePeriod() {
        var game = Game(
            board: Board(width: Tuning.boardW, height: Tuning.boardH),
            qix: [qixAt((0, 0))],
            sparx: [],
            rng: Rng(seed: gameSeed)
        )
        dieByFuse(&game)
        XCTAssert(game.graceTicks > 0)

        game.startLevel(nextLevel)

        XCTAssertEqual(game.graceTicks, 0)
    }

    func testStartingALevelAfterCompletingOnePlaysOn() {
        var game = aCompletedLevel()
        let threshold = game.claimThreshold

        game.startLevel(nextLevel)
        let ticks = game.ticks
        game.tick(InputState())

        XCTAssertFalse(game.isLevelComplete)
        XCTAssertEqual(game.ticks, ticks + 1)
        XCTAssertEqual(game.claimThreshold, threshold)
    }

    func testStartingALevelKeepsTheTickCount() {
        var game = newGame()
        game.tick(InputState())

        game.startLevel(nextLevel)

        XCTAssertEqual(game.ticks, 1)
    }

    func testARestartStartsANewGame() {
        var game = aPlayedGame()
        game.startLevel(nextLevel)
        game.setMultiplier(Tuning.startingMultiplier + 1)
        game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))

        game.restart()

        assertSetUpFor(game, Tuning.firstLevel)
        XCTAssertEqual(game.ticks, 0)
        XCTAssertEqual(game.lives, Tuning.startingLives)
        XCTAssertEqual(game.score.points, 0)
        XCTAssertEqual(game.multiplier, Tuning.startingMultiplier)
        XCTAssertEqual(game.claimThreshold, ClaimThreshold())
    }

    func testARestartFreesTheBoard() {
        var game = aPlayedGame()
        XCTAssert(game.board.claimedFraction() > 0.0, "nothing claimed")

        game.restart()

        XCTAssertEqual(game.board, Board(width: Tuning.boardW, height: Tuning.boardH))
    }

    func testARestartKeepsTheSizeOfTheBoard() {
        var game = Game(
            board: Board(width: smallWidth, height: smallHeight),
            qix: [qixAt((0, 0))],
            sparx: [],
            rng: Rng(seed: gameSeed)
        )

        game.restart()

        XCTAssertEqual(game.board.width, smallWidth)
        XCTAssertEqual(game.board.height, smallHeight)
    }

    func testANewGameHasTheDefaultRules() {
        XCTAssertEqual(newGame().rules, Rules())
    }

    func testNewRulesWaitForTheRestart() {
        var game = newGame()

        game.setRules(rules())

        XCTAssertEqual(game.rules, rules())
        XCTAssertEqual(game.lives, Tuning.startingLives)
        XCTAssertEqual(game.claimThreshold, ClaimThreshold())
    }

    func testARestartSetsTheGameUpByItsRules() {
        var game = aPlayedGame()
        game.setRules(rules())

        game.restart()

        XCTAssertEqual(game.lives, rulesLives)
        XCTAssertEqual(game.claimThreshold, rules().threshold)
        XCTAssertEqual(game.rules, rules())
    }

    func testARestartDropsAThresholdSetOutsideTheRules() {
        var game = newGame()
        game.setRules(rules())
        game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))

        game.restart()

        XCTAssertEqual(game.claimThreshold, rules().threshold)
    }

    func testStartingALevelKeepsTheRules() {
        var game = newGame()
        game.setRules(rules())

        game.startLevel(nextLevel)

        XCTAssertEqual(game.rules, rules())
    }
}
