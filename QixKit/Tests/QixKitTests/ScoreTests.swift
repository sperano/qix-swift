import XCTest
@testable import QixKit

/// Cells of the claims the tests score.
private let cells = 37

/// A level multiplier above one.
private let multiplier: UInt32 = 3

/// Steps of `Tuning.extraLifeEvery` the several-steps tests cross at once.
private let steps: UInt32 = 3

private func score(_ points: UInt32) -> Score {
    var score = Score()
    score.add(points)
    return score
}

private func claim(_ cells: Int, _ kind: DrawKind) -> ClaimResult {
    ClaimResult(cells: cells, fraction: 0.5, kind: kind)
}

final class ScoreTests: XCTestCase {
    func testAFastClaimScoresItsCellsAtPointsPerCell() {
        let points = scoreForClaim(claim(cells, .fast), 1)

        XCTAssertEqual(points, UInt32(cells) * Tuning.pointsPerCell)
    }

    func testTheLevelMultiplierScalesThePoints() {
        let points = scoreForClaim(claim(cells, .fast), multiplier)

        XCTAssertEqual(points, UInt32(cells) * Tuning.pointsPerCell * multiplier)
    }

    func testASlowClaimScoresTheSlowDrawFactorTimesAFastOne() {
        let fast = scoreForClaim(claim(cells, .fast), multiplier)
        let slow = scoreForClaim(claim(cells, .slow), multiplier)

        XCTAssertEqual(slow, fast * Tuning.slowDrawFactor)
    }

    func testAClaimTooLargeToCountSaturates() {
        let points = scoreForClaim(claim(.max, .slow), multiplier)

        XCTAssertEqual(points, .max)
    }

    func testAClaimOneCellPastWhatACountHoldsSaturatesRatherThanWrapping() {
        let points = scoreForClaim(claim(Int(UInt32.max) + 1, .fast), 1)

        XCTAssertEqual(points, .max)
    }

    func testANewScoreIsZero() {
        XCTAssertEqual(Score().points, 0)
    }

    func testAddAccumulatesPoints() {
        var score = Score()

        score.add(5)
        score.add(7)

        XCTAssertEqual(score.points, 12)
    }

    func testAddSaturatesAtTheMaximum() {
        var score = Score()

        score.add(.max - 1)
        score.add(2)

        XCTAssertEqual(score.points, .max)
    }

    func testPointsBelowTheNextStepEarnNoLife() {
        let lives = extraLives(score(1), score(Tuning.extraLifeEvery - 1), Tuning.startingLives)

        XCTAssertEqual(lives, 0)
    }

    func testReachingAStepExactlyEarnsALife() {
        let lives = extraLives(
            score(Tuning.extraLifeEvery - 1),
            score(Tuning.extraLifeEvery),
            Tuning.startingLives
        )

        XCTAssertEqual(lives, 1)
    }

    func testPointsFromAStepToBelowTheNextEarnNoLife() {
        let before = score(Tuning.extraLifeEvery)

        let lives = extraLives(before, score(2 * Tuning.extraLifeEvery - 1), Tuning.startingLives)

        XCTAssertEqual(lives, 0)
    }

    func testCrossingSeveralStepsAtOnceEarnsALifeForEach() {
        let after = score(steps * Tuning.extraLifeEvery + 1)

        let lives = extraLives(score(Tuning.extraLifeEvery - 1), after, Tuning.startingLives)

        XCTAssertEqual(lives, steps)
    }

    func testExtraLivesStopAtTheMaximum() {
        let after = score(steps * Tuning.extraLifeEvery)

        let lives = extraLives(Score(), after, Tuning.maxLives - 1)

        XCTAssertEqual(lives, 1)
    }

    func testAPlayerAtTheMaximumEarnsNoLife() {
        let after = score(steps * Tuning.extraLifeEvery)

        XCTAssertEqual(extraLives(Score(), after, Tuning.maxLives), 0)
        XCTAssertEqual(extraLives(Score(), after, Tuning.maxLives + 1), 0)
    }

    func testASaturatedScoreEarnsNoMoreLives() {
        let lives = extraLives(score(.max), score(.max), 1)

        XCTAssertEqual(lives, 0)
    }
}
