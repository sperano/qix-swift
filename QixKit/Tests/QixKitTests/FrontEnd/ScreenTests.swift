import XCTest
@testable import QixKit

/// Seed of the games the tests start from the title.
private let screenSeed: UInt64 = 1

/// The cells the stix of `claimedGame` claims.
private let claimedCells: UInt32 = 2

/// The points of the game `lostGame` plays.
private let lostGamePoints = "25,120"

/// The game-over line of a score that makes the table.
private let newHighScore = "A new high score!"

private func entry(_ name: String, _ score: UInt32) throws -> HighScore {
    try HighScore(name: Initials(name), score: score)
}

/// A table of `Tuning.highScoreCount` entries no game can beat.
private func unbeatableTable() throws -> HighScores {
    try HighScores(Array(repeating: entry("TOP", .max), count: Tuning.highScoreCount))
}

/// A game on a 4 x 2 board with a still Qix in its bottom-right cell that drew a fast stix up and
/// left from the marker's start, claiming the `claimedCells` cells of the bottom row's left half.
private func claimedGame(file: StaticString = #filePath, line: UInt = #line) -> Game {
    var game = Game(board: Board(width: 4, height: 2), qix: [qixAt((3, 1))], sparx: [], rng: Rng(seed: screenSeed))
    for (dir, steps) in [(Dir.up, UInt32(1)), (.left, UInt32(2))] {
        for _ in 0 ..< steps * Tuning.markerStepTicks {
            game.tick(InputState(dir: dir, fast: true))
        }
    }
    XCTAssertNil(game.stix, "the stix did not close", file: file, line: line)
    return game
}

/// A session with `highScores` that completed a level, then lost every life, with points: on its
/// game-over screen.
private func lostGame(_ highScores: HighScores, file: StaticString = #filePath, line: UInt = #line) -> Session {
    var session = completedLevel(with: highScores)
    session.tick(confirmInput)
    for _ in 0 ..< maxGameTicks where session.state != .gameOver {
        session.tick(InputState())
    }
    XCTAssertEqual(session.state, .gameOver, file: file, line: line)
    return session
}

/// `completedLevel`, in a session with `highScores`.
private func completedLevel(with highScores: HighScores) -> Session {
    var session = Session(game: levelGame(), highScores: highScores)
    session.tick(confirmInput)
    hold(&session, drawUpInput, UInt32(levelGameHeight) * Tuning.markerStepTicks)
    return session
}

final class ScreenTests: XCTestCase {
    func testANewSessionShowsTheTitleScreen() {
        XCTAssertEqual(Screen(session: Session(game: Game(rng: Rng(seed: screenSeed)))), .title(HighScores()))
    }

    func testASessionWithHighScoresShowsThemOnTheTitle() throws {
        let table = try HighScores([entry("QIX", 12_345), HighScore(name: .first, score: 10)])
        let session = Session(game: Game(rng: Rng(seed: screenSeed)), highScores: table)

        let shown = try XCTUnwrap(Screen(session: session))

        XCTAssertEqual(shown.table, ["1. QIX  12,345", "2. AAA      10"])
        XCTAssertEqual(shown, .title(table))
    }

    func testTheTitleScreenListsTheControls() {
        XCTAssertEqual(
            Screen.title(HighScores()),
            Screen(
                heading: "QIX",
                lines: [
                    "Arrows: move",
                    "hold Z while moving: draw fast",
                    "hold X while moving: draw slow, x2 points",
                    "Escape or the pause button: pause",
                    "",
                    "Tap or press Return to start",
                ]
            )
        )
    }

    func testTheDemosBannerSaysATapPlays() {
        XCTAssertEqual(Screen.demo, Screen(heading: "DEMO", lines: ["Tap or press Return to play"]))
    }

    func testPlayingShowsNoScreen() {
        XCTAssertNil(Screen(session: playing(Game(rng: Rng(seed: screenSeed)))))
    }

    func testAPausedSessionShowsThePauseScreen() {
        var session = playing(Game(rng: Rng(seed: screenSeed)))
        session.tick(pauseInput)

        XCTAssertEqual(Screen(session: session), .paused)
        XCTAssertEqual(Screen.paused.lines, ["Press Escape or the pause button to resume"])
    }

    func testACompletedLevelShowsTheClaimTheBonusAndTheMultiplier() {
        var game = Game(rng: Rng(seed: screenSeed))
        game.setMultiplier(3)

        XCTAssertEqual(
            Screen.levelComplete(game, fraction: 0.8125, bonus: 6_000, split: false),
            Screen(
                heading: "LEVEL 1 COMPLETE",
                lines: ["Claimed 81.2%", "Bonus 6,000", "Multiplier x3", "", "Tap or press Return for level 2"]
            )
        )
    }

    func testASplitSaysSoAboveTheClaim() {
        let lines = Screen.levelComplete(Game(rng: Rng(seed: screenSeed)), fraction: 0.5, bonus: 0, split: true).lines

        XCTAssertEqual(Array(lines.prefix(2)), ["The Qix are split apart!", "Claimed 50.0%"])
    }

    func testACompletedLevelOfASessionShowsItsClaimAndBonus() throws {
        let session = completedLevel()
        guard case let .levelComplete(fraction, bonus, split) = session.state else {
            return XCTFail("level not complete: \(session.state)")
        }

        let shown = try XCTUnwrap(Screen(session: session))

        XCTAssertEqual(shown, .levelComplete(session.game, fraction: fraction, bonus: bonus, split: split))
        XCTAssertEqual(Array(shown.lines.prefix(2)), ["Claimed 75.0%", "Bonus 25,000"])
    }

    func testASplitLevelOfASessionSaysSo() throws {
        let session = splitLevel()
        guard case .levelComplete(_, _, split: true) = session.state else {
            return XCTFail("level not split: \(session.state)")
        }

        let shown = try XCTUnwrap(Screen(session: session))

        XCTAssertEqual(shown.lines.first, "The Qix are split apart!")
    }

    func testGameOverShowsTheFinalScore() {
        let game = claimedGame()
        let points = claimedCells * Tuning.pointsPerCell

        XCTAssertEqual(game.score.points, points)
        XCTAssertEqual(
            Screen.gameOver(game, HighScores()),
            Screen(
                heading: "GAME OVER",
                lines: ["Final score \(points)", newHighScore, "", "Tap or press Return to continue"]
            )
        )
    }

    func testGameOverSaysNothingOfAScoreOffTheTable() throws {
        let game = claimedGame()

        XCTAssertEqual(
            try Screen.gameOver(game, unbeatableTable()).lines,
            ["Final score \(game.score.points)", "", "Tap or press Return to continue"]
        )
    }

    func testTheFinalScoreHasThousandsSeparators() {
        let game = completedLevel().game

        XCTAssertEqual(Screen.gameOver(game, HighScores()).lines[0], "Final score \(lostGamePoints)")
    }

    func testALostGameShowsTheGameOverScreen() {
        let (session, _) = playedToGameOver()

        XCTAssertEqual(session.state, .gameOver)
        XCTAssertEqual(Screen(session: session), .gameOver(session.game, session.highScores))
    }

    func testALostGameThatMakesTheTableSaysSo() throws {
        let session = lostGame(HighScores())

        XCTAssertTrue(try XCTUnwrap(Screen(session: session)).lines.contains(newHighScore))
    }

    func testALostGameOffTheSessionsTableSaysNothingOfAHighScore() throws {
        let session = try lostGame(unbeatableTable())

        let lines = try XCTUnwrap(Screen(session: session)).lines

        XCTAssertEqual(lines[0], "Final score \(lostGamePoints)")
        XCTAssertFalse(lines.contains(newHighScore), "\(lines)")
    }
}

final class HighScoreTableTests: XCTestCase {
    func testAnEmptyTableHasNoRows() {
        XCTAssertEqual(HighScoreTable.rows(HighScores()), [])
    }

    func testRowsAlignTheirRanksAndScores() throws {
        var list = try [entry("QIX", 1_234_567), entry("ABC", 50)]
        list += try (1 ..< Tuning.highScoreCount).map { try entry("ZZZ", UInt32($0)) }

        let rows = HighScoreTable.rows(HighScores(list))

        XCTAssertEqual(rows.count, Tuning.highScoreCount)
        XCTAssertEqual(rows[0], " 1. QIX  1,234,567")
        XCTAssertEqual(rows[1], " 2. ABC         50")
        XCTAssertEqual(rows[Tuning.highScoreCount - 1], "10. ZZZ          2")
    }

    func testAShortTablePadsNothingItDoesNotNeed() throws {
        let table = try HighScores([entry("ONE", 900), entry("TWO", 10)])

        XCTAssertEqual(HighScoreTable.rows(table), ["1. ONE  900", "2. TWO   10"])
    }

    func testTheEntryScreenShowsTheScoreItsRankAndWhatToType() throws {
        let game = claimedGame()
        let points = claimedCells * Tuning.pointsPerCell
        let table = try HighScores([entry("TOP", points + 1)])

        XCTAssertEqual(
            Screen.highScoreEntry(game, table),
            Screen(heading: "NEW HIGH SCORE", lines: ["Score \(points), rank 2", "Type your initials, then Done"])
        )
    }

    func testASessionEnteringInitialsShowsTheEntryScreen() throws {
        var session = lostGame(HighScores())
        session.tick(confirmInput)
        guard case .highScoreEntry = session.state else {
            return XCTFail("not entering initials: \(session.state)")
        }

        let shown = try XCTUnwrap(Screen(session: session))

        XCTAssertEqual(shown, .highScoreEntry(session.game, session.highScores))
        XCTAssertEqual(shown.lines[0], "Score \(lostGamePoints), rank 1")
    }

    func testTheEntryScreenRanksTheScoreInTheSessionsTable() throws {
        var session = try lostGame(HighScores([entry("TOP", .max)]))
        session.tick(confirmInput)

        XCTAssertEqual(try XCTUnwrap(Screen(session: session)).lines[0], "Score \(lostGamePoints), rank 2")
    }
}
