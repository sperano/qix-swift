import XCTest
@testable import QixKit

final class RulesTests: XCTestCase {
    func testStartingLivesInTheRangeAreKept() {
        for lives in Tuning.startingLivesRange {
            XCTAssertEqual(StartingLives(lives).get, lives)
        }
    }

    func testStartingLivesOutsideTheRangeAreClampedIntoIt() {
        let (fewest, most) = (Tuning.startingLivesRange.lowerBound, Tuning.startingLivesRange.upperBound)

        XCTAssertEqual(StartingLives(0).get, fewest)
        XCTAssertEqual(StartingLives(most + 1).get, most)
        XCTAssertEqual(StartingLives(.max).get, most)
    }

    func testAGameMayStartWithUpToTheMostLives() {
        XCTAssertEqual(Tuning.startingLivesRange.upperBound, Tuning.maxLives)
    }

    func testStartingLivesConvertThroughTheirNumberClamped() {
        // qix-rs checks `From<u32>` and `u32::from`, which are the `StartingLives` init and `get` in
        // Swift; comparing with the lowest count instead of a second `StartingLives(0)` keeps the
        // clamp visible.
        XCTAssertEqual(StartingLives(Tuning.startingLives).get, Tuning.startingLives)
        XCTAssertEqual(StartingLives(0), StartingLives(Tuning.startingLivesRange.lowerBound))
    }

    func testStartingLivesFromAWiderNumberAreClamped() {
        let (fewest, most) = (Tuning.startingLivesRange.lowerBound, Tuning.startingLivesRange.upperBound)

        XCTAssertEqual(StartingLives(clamping: -1).get, fewest)
        XCTAssertEqual(StartingLives(clamping: .min).get, fewest)
        XCTAssertEqual(StartingLives(clamping: Int64(Tuning.startingLives)).get, Tuning.startingLives)
        XCTAssertEqual(StartingLives(clamping: Int64(UInt32.max) + 1).get, most)
        XCTAssertEqual(StartingLives(clamping: .max).get, most)
    }

    func testTheDefaultRulesAreTheArcadeOnes() {
        let rules = Rules()

        XCTAssertEqual(rules.threshold, ClaimThreshold())
        XCTAssertEqual(rules.startingLives.get, Tuning.startingLives)
    }
}
