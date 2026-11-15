// Scripted deterministic playthroughs: fixed sequences of `InputState`s fed to a `Session` over a
// full-size `Game` with a fixed seed, from the title screen through a completed level and a game
// over to the high score table.
//
// The scripts are tuned for `playthroughSeed`: a change to the rules, the tuning or the order the
// game draws from its `Rng` changes where the Qix and the Sparx go, so these tests are expected to
// need a new seed or script when that happens on purpose.

import XCTest
@testable import QixKit

/// Seed of every game the playthroughs play.
private let playthroughSeed: UInt64 = 0

/// The board's dimensions, as the scripts count them.
private let boardW = UInt32(Tuning.boardW)
private let boardH = UInt32(Tuning.boardH)

/// The column of the marker's start, the centre of the bottom edge.
private let startX = boardW / 2

/// The column of the first stix, up the whole board: the Qix is right of it, so the cells left of
/// it are claimed.
private let leftLineX: UInt32 = 56

/// The column of the second stix, down the whole board: the Qix is left of it, so the cells right
/// of it are claimed.
private let rightLineX: UInt32 = 104

/// The row of the third stix, across the free columns between the first two: the Qix is below it,
/// so the cells above it are claimed.
private let cutY: UInt32 = 60

/// Lattice steps of the stix up the middle that the Qix runs into on the second level: up to the
/// middle row, where it starts.
private let intoQixSteps = boardH / 2

/// Lattice steps of the short stix the marker stops on, which the fuse burns along.
private let fuseStixSteps: UInt32 = 4

/// Ticks the marker stands still on its stix: exactly as many as the fuse needs to be lit and to
/// burn to the marker. The fuse burns one stix segment every `Tuning.fuseStepTicks`, and the
/// straight stix of `fuseStixSteps` lattice steps is a single segment.
private let standTicks = Tuning.fuseDelayTicks + Tuning.fuseStepTicks

/// Ticks of the grace period after a death that the script sits out.
private let graceWaitTicks = Tuning.respawnGraceTicks

/// Ticks the marker waits on the border for the Sparx to take every life left: far more than they
/// need.
private let waitForSparxTicks: UInt32 = 20_000

/// The cells each stix of the first level claims, in order.
private let levelOneClaims: [UInt32] = [
    leftLineX * boardH,
    (boardW - rightLineX) * boardH,
    (rightLineX - leftLineX) * cutY,
]

/// The first level's claimed share at its end, in whole percent points.
private let levelOnePercent: UInt32 = 85

/// Percent points in the whole board.
private let percent: UInt32 = 100

/// The deaths of the second level, in order: the fuse of the stix the marker stops on, the Qix the
/// next stix runs into, then the Sparx for every life left.
private let levelTwoDeaths: [DeathCause] = [.fuse, .qix, .sparx, .sparx, .sparx, .sparx, .sparx, .sparx]

/// A press of confirm, for one tick.
private let confirmStep = DemoStep(input: InputState(confirm: true), ticks: 1)

/// A walk of `steps` lattice steps along the border.
private func walk(_ dir: Dir, _ steps: UInt32) -> DemoStep {
    .walk(dir, steps * Tuning.markerStepTicks)
}

/// A fast draw of `steps` lattice steps.
private func fast(_ dir: Dir, _ steps: UInt32) -> DemoStep {
    .draw(dir, .fast, steps * Tuning.markerStepTicks)
}

/// From the title screen, the first level: a stix up column `leftLineX`, one down column
/// `rightLineX`, then one along row `cutY` between them, from the second back to the first.
private let levelOne: [DemoStep] = [
    confirmStep,
    walk(.left, startX - leftLineX),
    fast(.up, boardH),
    walk(.right, rightLineX - leftLineX),
    fast(.down, boardH),
    walk(.up, boardH - cutY),
    fast(.left, rightLineX - leftLineX),
]

/// From the end of the first level, the start of the second until the fuse kills: a short stix the
/// marker stops on.
private let levelTwoFuse: [DemoStep] = [
    confirmStep,
    fast(.up, fuseStixSteps),
    .idle(standTicks),
]

/// The rest of the second level, until the game is over: the grace period, a stix into the Qix,
/// then a wait on the border.
private let levelTwoRest: [DemoStep] = [
    .idle(graceWaitTicks),
    fast(.up, intoQixSteps),
    .idle(waitForSparxTicks),
]

/// The whole second level: `levelTwoFuse`, then `levelTwoRest`.
private let levelTwo = levelTwoFuse + levelTwoRest

/// From the game over screen, the initials of a first entry in the table: confirm moves on to the
/// initials, then confirms each of their letters as it starts.
private let enterInitials = [confirmStep, confirmStep, confirmStep, confirmStep]

/// A session on the title screen, over a new full-size game seeded with `playthroughSeed`.
private func newSession() -> Session {
    Session(game: Game(rng: Rng(seed: playthroughSeed)))
}

/// Plays `script` on `session` and returns the events of every tick, in order, but for the stix
/// steps.
private func play(_ session: inout Session, _ script: [DemoStep]) -> [Event] {
    var events: [Event] = []
    for step in script {
        for _ in 0 ..< step.ticks {
            session.tick(step.input)
            events += session.events.filter { if case .draw = $0 { false } else { true } }
        }
    }
    return events
}

/// The cells of the claims among `events`.
private func claims(_ events: [Event]) -> [UInt32] {
    events.compactMap { if case let .claim(cells, _) = $0 { UInt32(exactly: cells) } else { nil } }
}

/// The causes of the deaths among `events`.
private func deaths(_ events: [Event]) -> [DeathCause] {
    events.compactMap { if case let .death(cause) = $0 { cause } else { nil } }
}

/// The number of `Event.extraLife` among `events`.
private func extraLives(_ events: [Event]) -> UInt32 {
    UInt32(events.count { $0 == .extraLife })
}

/// The bonus of the first level: every whole percent point above the default threshold.
private func levelOneBonus() -> UInt32 {
    let threshold = UInt32((Tuning.claimThresholdDefault * Float(percent)).rounded())
    return (levelOnePercent - threshold) * Tuning.bonusPerPercent
}

/// The score at the end of the first level: every claimed cell at the starting multiplier of one,
/// plus the level bonus.
private func levelOneScore() -> UInt32 {
    levelOneClaims.reduce(0, +) * Tuning.pointsPerCell + levelOneBonus()
}

final class PlaythroughTests: XCTestCase {
    func testTheFirstLevelIsCompletedWithoutADeath() {
        var session = newSession()
        let events = play(&session, levelOne)
        let score = levelOneScore()
        let earned = score / Tuning.extraLifeEvery
        XCTAssertEqual(claims(events), levelOneClaims)
        XCTAssertEqual(deaths(events), [])
        XCTAssertEqual(extraLives(events), earned)
        XCTAssertEqual(
            session.state,
            .levelComplete(fraction: Float(levelOnePercent) / Float(percent), bonus: levelOneBonus(), split: false)
        )
        let game = session.game
        XCTAssertEqual(game.level, Tuning.firstLevel)
        XCTAssertEqual(game.score.points, score)
        XCTAssertEqual(game.lives, Tuning.startingLives + earned)
    }

    func testTheSecondLevelLosesEveryLifeAndScoresNothing() {
        var session = newSession()
        _ = play(&session, levelOne)
        let lives = session.game.lives
        let events = play(&session, levelTwo)
        XCTAssertEqual(deaths(events), levelTwoDeaths)
        XCTAssertEqual(levelTwoDeaths.count, Int(lives))
        XCTAssertEqual(claims(events), [])
        XCTAssertEqual(events.last, .gameOver)
        XCTAssertEqual(session.state, .gameOver)
        let game = session.game
        XCTAssertEqual(game.level, Tuning.firstLevel + 1)
        XCTAssertEqual(game.score.points, levelOneScore())
        XCTAssertEqual(game.lives, 0)
    }

    func testTheFuseReachesTheMarkerOnTheLastStandTick() throws {
        var session = newSession()
        _ = play(&session, levelOne)
        let lastTick = try XCTUnwrap(levelTwoFuse.last, "a stand")
        let early = DemoStep.idle(lastTick.ticks - 1)
        let events = play(&session, levelTwoFuse.dropLast() + [early])
        XCTAssertEqual(deaths(events), [])
        let lastEvents = play(&session, [.idle(1)])
        XCTAssertEqual(lastEvents, [.death(.fuse)])
    }

    func testTheFinalScoreEntersTheHighScoreTable() {
        var session = newSession()
        _ = play(&session, levelOne)
        _ = play(&session, levelTwo)
        _ = play(&session, enterInitials)
        XCTAssertEqual(session.state, .title)
        let entry = HighScore(name: .first, score: levelOneScore())
        XCTAssertEqual(session.highScores.entries, [entry])
        XCTAssertEqual(session.highScore, levelOneScore())
        let game = session.game
        XCTAssertEqual(game.level, Tuning.firstLevel)
        XCTAssertEqual(game.score.points, 0)
        XCTAssertEqual(game.lives, Tuning.startingLives)
    }

    func testTheSameScriptPlaysTheSameGameTwice() {
        let whole = levelOne + levelTwo
        var first = newSession()
        var second = newSession()
        XCTAssertEqual(play(&first, whole), play(&second, whole))
        XCTAssertEqual(first.game.ticks, second.game.ticks)
        XCTAssertEqual(first.game.board, second.game.board)
        XCTAssertEqual(first.game.marker, second.game.marker)
    }
}
