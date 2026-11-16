import Foundation
import XCTest
@testable import QixKit

/// Cells of a full-size board.
private let fullBoardCells = UInt32(Tuning.boardW) * UInt32(Tuning.boardH)

/// The last level of the difficulty ramp.
private let rampEnd = Tuning.firstLevel + Tuning.difficultyRampLevels

/// The last level the difficulty tests walk to: well past the ramp.
private let lastLevelTested = rampEnd + Tuning.difficultyRampLevels

/// Qix of a level before `Tuning.twoQixFromLevel`, and from it on.
private let oneQix = 1
private let twoQix = 2

/// The Sparx of each level of the ramp, from `Tuning.firstLevel` to
/// `rampEnd`: one more every two levels.
private let rampSparx = [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7]

/// The level after the first, and its Qix speeds and meter.
private let secondLevel = Tuning.firstLevel + 1
private let secondLevelQixSpeed: ClosedRange<Float> = 0.32 ... 0.82
private let secondLevelMeterTicks = 28 * Tuning.tickHz

/// The Qix speeds and the meter at the end of the ramp.
private let rampEndQixSpeed: ClosedRange<Float> = 0.5 ... 1.0
private let rampEndMeterTicks = 10 * Tuning.tickHz

/// Rounding slack on the speeds the ramp adds up.
private let speedEpsilon: Float = 1e-5

/// Whole percent points in a board.
private let whole: UInt32 = 100

/// Bonus steps, in whole percent points, between the lowest threshold and a full board.
private let lowestThresholdSteps: UInt32 = 50

/// Numbers past `Double`'s range, as stored, either side of it.
private let pastDouble = "1e400"
private let belowDouble = "-1e400"

/// `speed` is `expected`, but for rounding.
private func assertSpeed(
    _ speed: ClosedRange<Float>,
    _ expected: ClosedRange<Float>,
    _ level: UInt32,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    func close(_ one: Float, _ other: Float) -> Bool {
        abs(one - other) < speedEpsilon
    }
    XCTAssert(
        close(speed.lowerBound, expected.lowerBound) && close(speed.upperBound, expected.upperBound),
        "level \(level): \(speed), not \(expected)",
        file: file,
        line: line
    )
}

final class LevelTests: XCTestCase {
    func testTheDefaultThresholdIsTheTunedDefault() {
        XCTAssertEqual(ClaimThreshold().fraction, Tuning.claimThresholdDefault)
    }

    func testAThresholdInRangeIsKept() {
        XCTAssertEqual(ClaimThreshold(0.6).fraction, 0.6)
    }

    func testAThresholdOutOfRangeIsClampedIntoIt() {
        let (low, high) = (Tuning.claimThresholdRange.lowerBound, Tuning.claimThresholdRange.upperBound)

        XCTAssertEqual(ClaimThreshold(0.1).fraction, low)
        XCTAssertEqual(ClaimThreshold(1.0).fraction, high)
        XCTAssertEqual(ClaimThreshold(-.infinity).fraction, low)
        XCTAssertEqual(ClaimThreshold(.infinity).fraction, high)
    }

    func testANanThresholdIsTheDefault() {
        XCTAssertEqual(ClaimThreshold(.nan), ClaimThreshold())
    }

    func testExactlyTheThresholdReachesIt() {
        let threshold = ClaimThreshold()

        XCTAssert(threshold.isReached(Tuning.claimThresholdDefault))
        XCTAssert(threshold.isReached(1.0))
        XCTAssertFalse(threshold.isReached(Tuning.claimThresholdDefault.nextDown))
    }

    func testExactlyTheThresholdScoresNoBonus() {
        XCTAssertEqual(ClaimThreshold().bonus(Tuning.claimThresholdDefault), 0)
    }

    func testBelowTheThresholdScoresNoBonus() {
        XCTAssertEqual(ClaimThreshold().bonus(0.0), 0)
    }

    func testEveryWholePercentAboveTheThresholdScoresTheBonusPerPercent() {
        let threshold = ClaimThreshold()
        let at = UInt32(Tuning.claimThresholdDefault * Float(whole))

        for percent in at ... whole {
            let fraction = Float(percent) / Float(whole)
            let bonus = (percent - at) * Tuning.bonusPerPercent
            XCTAssertEqual(threshold.bonus(fraction), bonus, "\(percent) %")
        }
    }

    func testAPartOfAPercentScoresNothing() {
        let threshold = ClaimThreshold()

        XCTAssertEqual(threshold.bonus(0.759), 0)
        XCTAssertEqual(threshold.bonus(0.789), 3 * Tuning.bonusPerPercent)
    }

    func testTheBonusCountsFromAThresholdSetLower() {
        let threshold = ClaimThreshold(Tuning.claimThresholdRange.lowerBound)

        XCTAssertEqual(threshold.bonus(1.0), lowestThresholdSteps * Tuning.bonusPerPercent)
    }

    func testACellShortOfAWholePercentOnAFullBoardDoesNotReachIt() {
        let threshold = ClaimThreshold()
        func fraction(_ cells: UInt32) -> Float {
            Float(cells) / Float(fullBoardCells)
        }
        // One percent point above the default threshold.
        let cells = fullBoardCells / whole * 76

        XCTAssertEqual(threshold.bonus(fraction(cells)), Tuning.bonusPerPercent)
        XCTAssertEqual(threshold.bonus(fraction(cells - 1)), 0)
    }

    func testTheFirstLevelHasTheFirstLevelTuning() {
        XCTAssertEqual(
            LevelConfig.forLevel(Tuning.firstLevel),
            LevelConfig(
                qixSpeed: Tuning.qixSpeed,
                qixCount: oneQix,
                sparxCount: Tuning.levelSparx,
                meterTicks: Tuning.sparxMeterTicks
            )
        )
    }

    func testALevelBelowTheFirstPlaysAsTheFirst() {
        XCTAssertEqual(
            LevelConfig.forLevel(Tuning.firstLevel - 1),
            LevelConfig.forLevel(Tuning.firstLevel)
        )
    }

    func testDifficultyNeverDropsFromOneLevelToTheNext() {
        for level in Tuning.firstLevel ..< lastLevelTested {
            let (this, next) = (LevelConfig.forLevel(level), LevelConfig.forLevel(level + 1))
            XCTAssertGreaterThanOrEqual(next.qixSpeed.lowerBound, this.qixSpeed.lowerBound, "level \(level)")
            XCTAssertGreaterThanOrEqual(next.qixSpeed.upperBound, this.qixSpeed.upperBound, "level \(level)")
            XCTAssertGreaterThanOrEqual(next.qixCount, this.qixCount, "level \(level)")
            XCTAssertGreaterThanOrEqual(next.sparxCount, this.sparxCount, "level \(level)")
            XCTAssertLessThanOrEqual(next.meterTicks, this.meterTicks, "level \(level)")
        }
    }

    func testEachLevelOfTheRampHasFasterQixAndAShorterMeter() {
        for level in Tuning.firstLevel ..< rampEnd {
            let (this, next) = (LevelConfig.forLevel(level), LevelConfig.forLevel(level + 1))
            XCTAssertGreaterThan(next.qixSpeed.lowerBound, this.qixSpeed.lowerBound, "level \(level)")
            XCTAssertGreaterThan(next.qixSpeed.upperBound, this.qixSpeed.upperBound, "level \(level)")
            XCTAssertLessThan(next.meterTicks, this.meterTicks, "level \(level)")
        }
    }

    func testTheRampAddsASparxEveryTwoLevels() {
        for (level, sparx) in zip(Tuning.firstLevel ... rampEnd, rampSparx) {
            XCTAssertEqual(LevelConfig.forLevel(level).sparxCount, sparx, "level \(level)")
        }
    }

    func testTheSecondLevelIsOneStepUpTheRamp() {
        let config = LevelConfig.forLevel(secondLevel)

        assertSpeed(config.qixSpeed, secondLevelQixSpeed, secondLevel)
        XCTAssertEqual(config.meterTicks, secondLevelMeterTicks)
    }

    func testTheEndOfTheRampHasTheTopSpeedAndTheShortestMeter() {
        let config = LevelConfig.forLevel(rampEnd)

        assertSpeed(config.qixSpeed, rampEndQixSpeed, rampEnd)
        XCTAssertEqual(config.meterTicks, rampEndMeterTicks)
    }

    func testDifficultyStopsRisingAfterTheRamp() {
        let top = LevelConfig.forLevel(rampEnd)

        XCTAssertGreaterThan(top.meterTicks, 0)
        for level in [rampEnd + 1, lastLevelTested, UInt32.max] {
            XCTAssertEqual(LevelConfig.forLevel(level), top, "level \(level)")
        }
    }

    func testThereAreTwoQixFromLevelThreeOn() {
        XCTAssertEqual(Tuning.twoQixFromLevel, 3)
        for level in Tuning.firstLevel ..< Tuning.twoQixFromLevel {
            XCTAssertEqual(LevelConfig.forLevel(level).qixCount, oneQix, "level \(level)")
        }
        for level in Tuning.twoQixFromLevel ... lastLevelTested {
            XCTAssertEqual(LevelConfig.forLevel(level).qixCount, twoQix, "level \(level)")
        }
    }

    /// Swift only: Rust's `as u32` saturates where Swift's conversion would trap, so a share too
    /// large for `UInt32` scores the most bonus, and a NaN fraction none.
    func testTheBonusOfAShareTooLargeOrNaNSaturatesAsRustCastsIt() {
        let threshold = ClaimThreshold()

        XCTAssertEqual(threshold.bonus(.greatestFiniteMagnitude), .max)
        XCTAssertEqual(threshold.bonus(.nan), 0)
    }

    /// Stands for qix-rs's compile-time check in `level.rs`: the meter's countdowns stay positive
    /// at the end of the ramp, so `Tuning.sparxMeterTicks` outlasts what the ramp takes off it.
    func testTheMetersCountdownsStayPositiveAtTheEndOfTheRamp() {
        XCTAssertGreaterThan(
            Tuning.sparxMeterTicks,
            Tuning.difficultyRampLevels * Tuning.sparxMeterTicksPerLevel
        )
    }

    // Rust's serde derive, tested in qix-rs through the settings storage
    // (`crates/qix/src/settings_test.rs`): the threshold codes as its fraction, clamped on the way
    // in.

    func testAClaimThresholdEncodesAsItsFraction() throws {
        let data = try JSONEncoder().encode([ClaimThreshold()])

        XCTAssertEqual(String(bytes: data, encoding: .utf8), "[\(Tuning.claimThresholdDefault)]")
    }

    func testAStoredClaimThresholdIsClampedIntoTheRange() throws {
        let range = Tuning.claimThresholdRange
        let stored = "[\(Tuning.claimThresholdDefault), 0.1, 1.5]"

        let thresholds = try JSONDecoder().decode([ClaimThreshold].self, from: Data(stored.utf8))

        XCTAssertEqual(thresholds.map(\.fraction), [Tuning.claimThresholdDefault, range.lowerBound, range.upperBound])
    }

    func testAClaimThresholdThatIsNotANumberFailsToDecode() {
        for stored in [#"["high"]"#, "[null]"] {
            XCTAssertThrowsError(try JSONDecoder().decode([ClaimThreshold].self, from: Data(stored.utf8)), stored)
        }
    }

    func testAClaimThresholdPastDoubleFailsToDecode() {
        for stored in ["[\(pastDouble)]", "[\(belowDouble)]"] {
            XCTAssertThrowsError(try JSONDecoder().decode([ClaimThreshold].self, from: Data(stored.utf8)), stored) {
                XCTAssertTrue($0 is DecodingError, "\(stored): \($0)")
            }
        }
    }
}
