// `Session.setRules`: the title screen's game restarts with the new rules, a game in play keeps its
// own until the next one.

import XCTest
@testable import QixKit

/// The claim threshold and the starting lives of `rules`.
private let rulesThreshold: Float = 0.55
private let rulesLives: UInt32 = 7

/// Rules other than the default ones.
private func rules() -> Rules {
    let rules = Rules(threshold: ClaimThreshold(rulesThreshold), startingLives: StartingLives(rulesLives))
    XCTAssertNotEqual(rules, Rules())
    return rules
}

final class StateRulesTests: XCTestCase {
    func testNewRulesOnTheTitleScreenRestartItsGameWithThem() {
        var session = Session(game: Game(rng: Rng(seed: sessionSeed)))

        session.setRules(rules())

        XCTAssertEqual(session.state, .title)
        let game = session.game
        XCTAssertEqual(game.lives, rulesLives)
        XCTAssertEqual(game.claimThreshold, rules().threshold)
        XCTAssertEqual(game.ticks, 0)
    }

    func testTheGameStartedAfterNewRulesPlaysByThem() {
        var session = Session(game: Game(rng: Rng(seed: sessionSeed)))
        session.setRules(rules())

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.game.lives, rulesLives)
    }

    func testAGameInPlayKeepsItsOwnRules() {
        var session = playing(levelGame())
        let (lives, threshold) = (session.game.lives, session.game.claimThreshold)

        session.setRules(rules())

        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.game.lives, lives)
        XCTAssertEqual(session.game.claimThreshold, threshold)
    }

    func testTheGameAfterGameOverPlaysByTheNewRules() {
        var (session, _) = playedToGameOver()
        session.setRules(rules())

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .title)
        XCTAssertEqual(session.game.lives, rulesLives)
        XCTAssertEqual(session.game.claimThreshold, rules().threshold)
    }
}
