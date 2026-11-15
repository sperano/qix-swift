import XCTest
@testable import QixKit

// The helpers the `StateTests/` files share are internal, with names no other test file uses, except
// `hold`, which overloads GameTests' `hold(_:_:_:)` for a `Session`: one target holds them all.

/// Seed of every game the tests play.
let sessionSeed: UInt64 = 1_206

/// Dimensions of the board of `levelGame`: a stix up column `levelGameWidth / 2` from the marker's
/// start claims the cells right of it, leaving the Qix in cell `(0, 0)` on its left.
private let levelGameWidth: UInt16 = 8
let levelGameHeight: UInt16 = 3

/// Cells `levelGame` claims before the stix, clear of its column and of the top row: with the
/// stix, 18 cells of 24.
private let claimedBefore: [(UInt16, UInt16)] = [(0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2)]

/// The board's claimed fraction once the stix of `levelGame` closes.
private let fractionAfter: Float = 0.75

/// The claim threshold of `levelGame`, and the whole percent points `fractionAfter` is above it.
private let lowThreshold: Float = 0.5
private let percentAboveLow: UInt32 = 25

/// Dimensions of the board of `splitGame`: a stix up column `splitW / 2` from the marker's start
/// splits its two Qix.
private let splitW: UInt16 = 8
private let splitH: UInt16 = 4

/// The columns `splitGame` claims before the stix: the first walls a Qix into column 0, the others
/// narrow the area of the second Qix.
private let splitClaimedColumns: [UInt16] = [1, 6, 7]

/// The cells holding the Qix of `splitGame`, either side of the stix.
private let splitQixCells: [(UInt16, UInt16)] = [(0, 0), (5, 0)]

/// The board's claimed fraction once the stix of `splitGame` closes: 20 cells of 32, above
/// `lowThreshold`.
private let splitFraction: Float = 0.625

/// Dimensions of the board of `sparxGame`: its border is one loop the Sparx keeps walking.
private let sparxW: UInt16 = 4
private let sparxH: UInt16 = 2

/// Ticks `sparxGame`'s Sparx is given to take every life: far more than its laps of a `sparxW` x
/// `sparxH` border need.
let maxGameTicks: UInt32 = 10_000

/// Ticks the tests that expect nothing to happen run.
private let idleTicks: UInt32 = 20

/// Inputs with neither press, which no state but `GameState.playing` acts on, each held for
/// `idleTicks` by `assertWaits`.
private let otherInputs = [
    InputState(),
    InputState(dir: .up, fast: true),
    InputState(dir: .left, slow: true),
    InputState(dir: .right),
]

let confirmInput = InputState(confirm: true)

let pauseInput = InputState(pause: true)

/// Holding up with the fast-draw button.
let drawUpInput = InputState(dir: .up, fast: true)

/// A game on a `levelGameWidth x levelGameHeight` board with every cell of `claimedBefore`
/// claimed, the Qix in cell `(0, 0)`, no Sparx and `lowThreshold`: a stix up from the marker
/// completes the level.
func levelGame() -> Game {
    var board = Board(width: levelGameWidth, height: levelGameHeight)
    for (x, y) in claimedBefore {
        board.setCell(x: x, y: y, to: .claimed(.fast))
    }
    var game = Game(board: board, qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: sessionSeed))
    game.setClaimThreshold(ClaimThreshold(lowThreshold))
    return game
}

/// A game on a `splitW x splitH` board with `splitClaimedColumns` claimed, a Qix in each of
/// `splitQixCells`, no Sparx and `lowThreshold`: a stix up from the marker splits the Qix apart.
private func splitGame() -> Game {
    var board = Board(width: splitW, height: splitH)
    for x in splitClaimedColumns {
        for y in 0 ..< splitH {
            board.setCell(x: x, y: y, to: .claimed(.fast))
        }
    }
    var game = Game(board: board, qix: splitQixCells.map(qixAt), sparx: [], rng: Rng(seed: sessionSeed))
    game.setClaimThreshold(ClaimThreshold(lowThreshold))
    return game
}

/// A game on a free `sparxW x sparxH` board with a still Qix in its bottom-right cell and a Sparx
/// one step right of the marker heading for it: standing still, the marker loses a life every lap.
private func sparxGame() -> Game {
    let sparx = Sparx(pos: Point(x: sparxW / 2 + 1, y: sparxH), dir: .left, kind: .normal)
    let board = Board(width: sparxW, height: sparxH)
    return Game(board: board, qix: [qixAt((sparxW - 1, sparxH - 1))], sparx: [sparx], rng: Rng(seed: sessionSeed))
}

/// A session over `game`, confirmed past the title screen.
func playing(_ game: Game, file: StaticString = #filePath, line: UInt = #line) -> Session {
    var session = Session(game: game)
    session.tick(confirmInput)
    XCTAssertEqual(session.state, .playing, file: file, line: line)
    return session
}

/// Ticks `session` `ticks` times with `input`.
func hold(_ session: inout Session, _ input: InputState, _ ticks: UInt32) {
    for _ in 0 ..< ticks {
        session.tick(input)
    }
}

/// A session over `game`, `height` cells high, that drew a stix up from the marker's start to the
/// top edge.
private func drawUp(_ game: Game, _ height: UInt16) -> Session {
    var session = playing(game)
    hold(&session, drawUpInput, UInt32(height) * Tuning.markerStepTicks)
    return session
}

/// A `levelGame` played up to its completion.
func completedLevel() -> Session {
    drawUp(levelGame(), levelGameHeight)
}

/// A `sparxGame` played until the state leaves `GameState.playing`; also returns how many deaths
/// left it playing. qix-rs's `game_over`.
func playedToGameOver() -> (Session, UInt32) {
    var session = playing(sparxGame())
    var deathsPlaying: UInt32 = 0
    for _ in 0 ..< maxGameTicks {
        session.tick(InputState())
        if session.state != .playing {
            break
        }
        deathsPlaying += UInt32(session.game.events.count { if case .death = $0 { true } else { false } })
    }
    return (session, deathsPlaying)
}

/// Ticks `session` with each of `otherInputs` and asserts that neither its state nor its game
/// changes.
private func assertWaits(_ session: inout Session, file: StaticString = #filePath, line: UInt = #line) {
    let (state, game) = (session.state, session.game)
    for input in otherInputs {
        hold(&session, input, idleTicks)
        XCTAssertEqual(session.state, state, "\(input)", file: file, line: line)
        XCTAssertEqual(session.game, game, "\(input)", file: file, line: line)
    }
}

/// Whether `state` is `GameState.levelComplete`, whatever its claim and bonus.
func isLevelComplete(_ state: GameState) -> Bool {
    if case .levelComplete = state { true } else { false }
}

final class StateTests: XCTestCase {
    func testANewSessionIsOnTheTitleScreen() {
        let session = Session(game: levelGame())

        XCTAssertEqual(session.state, .title)
        XCTAssertEqual(session.game.ticks, 0)
    }

    func testTheTitleScreenWaitsForConfirm() {
        var session = Session(game: levelGame())

        assertWaits(&session)
        hold(&session, pauseInput, idleTicks)

        XCTAssertEqual(session.state, .title)
        XCTAssertEqual(session.game.ticks, 0)
    }

    func testConfirmOnTheTitleScreenStartsPlayFromTheNextTick() {
        var session = Session(game: levelGame())

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.game.ticks, 0)
        session.tick(InputState())
        XCTAssertEqual(session.game.ticks, 1)
    }

    func testPlayingTicksTheGameAndIgnoresConfirm() {
        var session = playing(levelGame())

        hold(&session, confirmInput, idleTicks)

        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.game.ticks, UInt64(idleTicks))
    }

    func testPauseWhilePlayingPausesBeforeTheGameTicks() {
        var session = playing(levelGame())
        session.tick(InputState())

        session.tick(pauseInput)

        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.game.ticks, 1)
    }

    func testTickingWhilePausedChangesNothing() {
        var session = playing(levelGame())
        hold(&session, drawUpInput, Tuning.markerStepTicks)
        XCTAssertNotNil(session.game.stix, "no stix to freeze")
        session.tick(pauseInput)

        assertWaits(&session)
        let game = session.game
        hold(&session, confirmInput, idleTicks)

        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.game, game, "confirm ticked")
        XCTAssertNotNil(session.game.stix)
    }

    func testPauseWhilePausedResumesPlay() {
        var session = playing(levelGame())
        session.tick(pauseInput)
        let ticks = session.game.ticks

        session.tick(pauseInput)

        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.game.ticks, ticks, "the resuming tick ticked")
        session.tick(InputState())
        XCTAssertEqual(session.game.ticks, ticks + 1)
    }

    func testACompletedLevelShowsItsClaimAndBonus() {
        let session = completedLevel()

        XCTAssertEqual(
            session.state,
            .levelComplete(fraction: fractionAfter, bonus: percentAboveLow * Tuning.bonusPerPercent, split: false)
        )
    }

    func testASplitLevelShowsItsClaimWithoutABonus() {
        let session = drawUp(splitGame(), splitH)

        XCTAssertEqual(session.state, .levelComplete(fraction: splitFraction, bonus: 0, split: true))
    }

    func testACompletedLevelWaitsForConfirm() {
        var session = completedLevel()

        assertWaits(&session)
        hold(&session, pauseInput, idleTicks)

        XCTAssertTrue(isLevelComplete(session.state), "\(session.state)")
    }

    func testConfirmAfterACompletedLevelPlaysTheNextLevel() {
        var session = completedLevel()
        let (score, ticks) = (session.game.score, session.game.ticks)

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .playing)
        let game = session.game
        XCTAssertEqual(game.level, Tuning.firstLevel + 1)
        XCTAssertEqual(game.board.claimedFraction(), 0)
        XCTAssertEqual(game.score, score)
        XCTAssertFalse(game.isLevelComplete)
        XCTAssertEqual(game.ticks, ticks, "the confirming tick ticked")
        session.tick(InputState())
        XCTAssertEqual(session.game.ticks, ticks + 1)
    }

    func testADeathWithLivesLeftKeepsPlaying() {
        let (_, deathsPlaying) = playedToGameOver()

        XCTAssertEqual(deathsPlaying, Tuning.startingLives - 1)
    }

    func testLosingTheLastLifeEndsTheGame() {
        let (session, _) = playedToGameOver()

        XCTAssertEqual(session.state, .gameOver)
        XCTAssertEqual(session.game.lives, 0)
    }

    func testGameOverWaitsForConfirm() {
        var (session, _) = playedToGameOver()

        assertWaits(&session)
        hold(&session, pauseInput, idleTicks)

        XCTAssertEqual(session.state, .gameOver)
    }

    func testConfirmAfterGameOverShowsTheTitleWithANewGame() {
        var (session, _) = playedToGameOver()

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .title)
        let game = session.game
        XCTAssertEqual(game.lives, Tuning.startingLives)
        XCTAssertEqual(game.ticks, 0)
        XCTAssertEqual(game.level, Tuning.firstLevel)
    }

    func testANewSessionHasNoHighScore() {
        XCTAssertEqual(Session(game: levelGame()).highScore, 0)
    }

    func testTheHighScoreFollowsTheScoreOfTheGamePlayed() {
        let session = completedLevel()

        let points = session.game.score.points
        XCTAssertGreaterThan(points, 0, "the level scored nothing")
        XCTAssertEqual(session.highScore, points)
    }

    func testTheHighScoreRisesDuringPlay() {
        var game = levelGame()
        game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.upperBound))
        var session = playing(game)
        for _ in 0 ..< UInt32(levelGameHeight) * Tuning.markerStepTicks {
            session.tick(drawUpInput)
            if session.game.score.points > 0 {
                break
            }
        }

        let points = session.game.score.points
        XCTAssertGreaterThan(points, 0, "the stix scored nothing")
        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.highScore, points)
    }

    func testTheHighScoreOutlivesTheGameThatSetIt() {
        var session = completedLevel()
        let best = session.highScore
        session.tick(confirmInput)
        for _ in 0 ..< maxGameTicks {
            if session.state == .gameOver {
                break
            }
            session.tick(InputState())
        }
        XCTAssertEqual(session.state, .gameOver)

        // One confirm leaves the game over screen, one per letter enters the initials.
        for _ in 0 ... Tuning.initialsLen {
            session.tick(confirmInput)
        }

        XCTAssertEqual(session.state, .title)
        XCTAssertEqual(session.game.score.points, 0)
        XCTAssertEqual(session.highScore, best)
    }
}
