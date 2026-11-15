import Foundation
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

    // Rust's serde derive, tested in qix-rs through the settings storage
    // (`crates/qix/src/settings_test.rs`): the lives code as their number, clamped on the way in.

    func testStartingLivesEncodeAsTheirNumber() throws {
        let data = try JSONEncoder().encode([StartingLives(Tuning.startingLives)])

        XCTAssertEqual(String(bytes: data, encoding: .utf8), "[\(Tuning.startingLives)]")
    }

    func testStoredStartingLivesAreClampedIntoTheRange() throws {
        let (fewest, most) = (Tuning.startingLivesRange.lowerBound, Tuning.startingLivesRange.upperBound)
        let stored = "[\(Tuning.startingLives), 0, 99, -1, 4294967296]"

        let lives = try JSONDecoder().decode([StartingLives].self, from: Data(stored.utf8))

        XCTAssertEqual(lives.map(\.get), [Tuning.startingLives, fewest, most, fewest, most])
    }

    func testStartingLivesThatAreNotAWholeNumberFailToDecode() {
        for stored in ["[2.5]", #"["three"]"#, "[null]"] {
            XCTAssertThrowsError(try JSONDecoder().decode([StartingLives].self, from: Data(stored.utf8)), stored)
        }
    }
}
