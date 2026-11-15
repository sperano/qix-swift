import XCTest
@testable import QixKit

/// The column of the full board the Qix is `pen`ned in, left of every stix the tests draw: each
/// claims the board right of its stix.
private let penColumn: UInt16 = 1

/// Lattice steps left of the marker's start the stix of `testTheLevelBonusCountsTowardsExtraLives`
/// runs up: far enough that its claim reaches the lowest threshold and scores a bonus.
private let bonusStixOffset: UInt32 = 40

/// A full-size game with no Sparx and its Qix penned in `penColumn`.
private func pennedGame() -> Game {
    var board = Board(width: Tuning.boardW, height: Tuning.boardH)
    let qix = pen(&board, penColumn)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// Draws the stix up from the marker to the top edge with `kind`, and checks that it closed.
private func closeUp(_ game: inout Game, _ kind: DrawKind) {
    draw(&game, .up, kind, UInt32(Tuning.boardH))
    XCTAssertNil(game.stix, "the stix did not close")
}

/// Draws the stix down from the marker on the top edge to the bottom edge with `kind`, and checks
/// that it closed.
private func closeDown(_ game: inout Game, _ kind: DrawKind) {
    draw(&game, .down, kind, UInt32(Tuning.boardH))
    XCTAssertNil(game.stix, "the stix did not close")
}

/// The `Event.extraLife` the last tick raised.
private func extraLifeEvents(_ game: Game) -> UInt32 {
    UInt32(game.events.filter { $0 == .extraLife }.count)
}

/// The multiples of `Tuning.extraLifeEvery` up to `points`.
private func steps(_ points: UInt32) -> UInt32 {
    points / Tuning.extraLifeEvery
}

/// Extra lives through `Game.tick`: one for every multiple of `Tuning.extraLifeEvery` the score
/// crosses, up to `Tuning.maxLives`.
final class GameExtraLivesTests: XCTestCase {
    func testAClaimCrossingSeveralStepsEarnsALifeForEach() {
        var game = pennedGame()

        closeUp(&game, .fast)

        let crossed = steps(game.score.points)
        XCTAssert(crossed > 1, "the claim crossed \(crossed) steps")
        XCTAssert(Tuning.startingLives + crossed <= Tuning.maxLives, "the cap was reached")
        XCTAssertEqual(game.lives, Tuning.startingLives + crossed)
        XCTAssertEqual(extraLifeEvents(game), crossed)
    }

    func testExtraLivesStopAtTheMaximum() {
        var game = pennedGame()
        game.setMultiplier(Tuning.maxMultiplier)

        closeUp(&game, .slow)

        let crossed = steps(game.score.points)
        XCTAssert(Tuning.startingLives + crossed > Tuning.maxLives, "the cap was not reached")
        XCTAssertEqual(game.lives, Tuning.maxLives)
        XCTAssertEqual(extraLifeEvents(game), Tuning.maxLives - Tuning.startingLives)
    }

    func testAClaimAtTheMaximumLivesEarnsNone() {
        var game = pennedGame()
        game.setMultiplier(Tuning.maxMultiplier)
        closeUp(&game, .slow)
        let score = game.score.points

        walk(&game, .left, 1)
        closeDown(&game, .slow)

        XCTAssert(steps(game.score.points) > steps(score), "no step crossed")
        XCTAssertEqual(game.lives, Tuning.maxLives)
        XCTAssertEqual(extraLifeEvents(game), 0)
    }

    func testTheLevelBonusCountsTowardsExtraLives() {
        var game = pennedGame()
        game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.lowerBound))
        walk(&game, .left, bonusStixOffset)

        closeUp(&game, .fast)

        guard case let .levelComplete(_, bonus, _)? = game.events.last else {
            return XCTFail("the level did not end: \(game.events)")
        }
        let score = game.score.points
        XCTAssert(steps(score - bonus) < steps(score), "the bonus crossed no step")
        XCTAssertEqual(game.lives, Tuning.startingLives + steps(score))
        XCTAssertEqual(extraLifeEvents(game), steps(score))
    }
}
