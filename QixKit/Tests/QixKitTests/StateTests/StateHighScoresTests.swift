// The high score table of a `Session`: a game over whose score makes it enters initials, which put
// the score in the table.

import XCTest
@testable import QixKit

/// The score of every entry of the table a session starts with.
private let oldScore: UInt32 = 1_234

/// The score of the entries a game's points beat.
private let lowScore: UInt32 = 1

/// Ticks the tests that expect the entry to wait run.
private let idleTicks: UInt32 = 20

/// Holding up, which steps the letter under the cursor.
private let up = InputState(dir: .up)

private func initials(_ text: String) throws -> Initials {
    try Initials(text)
}

/// A table of `Tuning.highScoreCount` entries all scoring `score`.
private func tableOf(_ score: UInt32) throws -> HighScores {
    try HighScores(Array(repeating: HighScore(name: initials("OLD"), score: score), count: Tuning.highScoreCount))
}

/// A session over `levelGame` with `table`, played until the game is over: it completes the first
/// level, then loses every life to the Sparx of the next one, with points.
private func scoredGameOver(_ table: HighScores, file: StaticString = #filePath, line: UInt = #line) -> Session {
    var session = Session(game: levelGame(), highScores: table)
    session.tick(confirmInput)
    hold(&session, drawUpInput, UInt32(levelGameHeight) * Tuning.markerStepTicks)
    XCTAssertTrue(isLevelComplete(session.state), "\(session.state)", file: file, line: line)
    session.tick(confirmInput)
    for _ in 0 ..< maxGameTicks {
        if session.state == .gameOver {
            break
        }
        session.tick(InputState())
    }
    XCTAssertEqual(session.state, .gameOver, file: file, line: line)
    XCTAssertGreaterThan(session.game.score.points, 0, "the game scored nothing", file: file, line: line)
    return session
}

/// Ticks `session` with confirm until the initials entry ends, and checks it took one confirm per
/// letter.
private func confirmInitials(_ session: inout Session, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 1 ..< Tuning.initialsLen {
        session.tick(confirmInput)
        guard case .highScoreEntry = session.state else {
            return XCTFail("\(session.state)", file: file, line: line)
        }
    }
    session.tick(confirmInput)
}

final class StateHighScoresTests: XCTestCase {
    func testASessionStartsWithTheBestScoreOfItsTable() throws {
        let table = try tableOf(oldScore)
        let session = Session(game: levelGame(), highScores: table)

        XCTAssertEqual(session.state, .title)
        XCTAssertEqual(session.highScores, table)
        XCTAssertEqual(session.highScore, oldScore)
    }

    func testANewSessionHasAnEmptyTable() {
        XCTAssertEqual(Session(game: levelGame()).highScores, HighScores())
    }

    func testConfirmAfterAQualifyingGameOverEntersInitials() {
        var session = scoredGameOver(HighScores())
        let points = session.game.score.points

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .highScoreEntry(InitialsEntry()))
        XCTAssertEqual(session.game.score.points, points)
    }

    func testTheEnteredInitialsPutTheScoreInTheTable() throws {
        var session = scoredGameOver(HighScores())
        let points = session.game.score.points
        session.tick(confirmInput)

        session.tick(up)
        confirmInitials(&session)

        XCTAssertEqual(session.state, .title)
        let expected = try HighScore(name: initials("BAA"), score: points)
        XCTAssertEqual(session.highScores.entries, [expected])
        XCTAssertEqual(session.game.score.points, 0)
        XCTAssertEqual(session.highScore, points)
    }

    func testTheEnteredInitialsGoAboveALowerScore() throws {
        let old = try HighScore(name: initials("OLD"), score: lowScore)
        var session = scoredGameOver(HighScores([old]))
        let points = session.game.score.points
        session.tick(confirmInput)

        confirmInitials(&session)

        let new = HighScore(name: .first, score: points)
        XCTAssertEqual(session.highScores.entries, [new, old])
    }

    func testAFullTableAdmitsAHigherScore() throws {
        var session = try scoredGameOver(tableOf(lowScore))
        let points = session.game.score.points

        session.tick(confirmInput)
        XCTAssertEqual(session.state, .highScoreEntry(InitialsEntry()))
        confirmInitials(&session)

        let entries = session.highScores.entries
        XCTAssertEqual(entries.count, Tuning.highScoreCount)
        XCTAssertEqual(entries.first, HighScore(name: .first, score: points))
        XCTAssertTrue(entries.dropFirst().allSatisfy { $0.score == lowScore })
    }

    func testTheEntryWaitsForItsInitials() {
        var session = scoredGameOver(HighScores())
        session.tick(confirmInput)
        let game = session.game

        hold(&session, pauseInput, idleTicks)
        hold(&session, InputState(), idleTicks)

        XCTAssertEqual(session.state, .highScoreEntry(InitialsEntry()))
        XCTAssertEqual(session.game, game)
    }

    func testAScoreOffAFullTableGoesBackToTheTitle() throws {
        var session = try scoredGameOver(tableOf(.max))
        let before = session.highScores

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .title)
        XCTAssertEqual(session.highScores, before)
    }

    func testAGameOverWithoutPointsSkipsTheEntry() {
        var (session, _) = playedToGameOver()
        XCTAssertEqual(session.game.score.points, 0)

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .title)
        XCTAssertTrue(session.highScores.entries.isEmpty)
    }
}
