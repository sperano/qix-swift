import Foundation
import XCTest
@testable import QixKit

/// The ranges the steppers show, in percent points: those of `Tuning` and the settings' types.
private let thresholdPercents = 50 ... 90
private let stickSizePercents = 75 ... 150
private let opacityPercents = 20 ... 100

/// The steps of the steppers, in percent points: qix-rs's 5 points for the threshold.
private let thresholdStep = 5
private let stickSizeStep = 25
private let opacityStep = 10

/// The defaults as the steppers show them, in percent points.
private let defaultThresholdPercent = 75
private let standardStickSizePercent = 100
private let standardOpacityPercent = 70

/// Values the steppers set inside their ranges, and what they set.
private let insideStickSizePercent = 125
private let insideStickSize: Float = 1.25
private let insideOpacityPercent = 40
private let insideOpacity: Float = 0.4
private let insideLives: UInt32 = 4

/// Values the steppers set outside their ranges.
private let aboveThresholdPercent = 95
private let belowStickSizePercent = 10
private let belowOpacityPercent = 0

/// Numbers past `Float`'s range, as stored, either side of it.
private let pastFloat = "1e39"
private let belowFloat = "-1e39"

/// Numbers past `Double`'s range, as stored, either side of it.
private let pastDouble = "1e400"
private let belowDouble = "-1e400"

/// Converts percent points to a fraction.
private let pointsPerUnit: Float = 100

/// Settings with every field off its default.
private func edited() -> Settings {
    let settings = Settings(
        threshold: ClaimThreshold(Tuning.claimThresholdRange.upperBound),
        startingLives: StartingLives(Tuning.startingLivesRange.lowerBound), controlScheme: .stick, leftHanded: true,
        stickSize: StickSize(StickSize.range.upperBound),
        controlsOpacity: ControlsOpacity(ControlsOpacity.range.lowerBound),
        haptics: false, sounds: true
    )
    let defaults = Settings()
    XCTAssertNotEqual(settings.threshold, defaults.threshold)
    XCTAssertNotEqual(settings.startingLives, defaults.startingLives)
    XCTAssertNotEqual(settings.leftHanded, defaults.leftHanded)
    XCTAssertNotEqual(settings.stickSize, defaults.stickSize)
    XCTAssertNotEqual(settings.controlsOpacity, defaults.controlsOpacity)
    XCTAssertNotEqual(settings.haptics, defaults.haptics)
    XCTAssertNotEqual(settings.sounds, defaults.sounds)
    return settings
}

/// The settings `json` decodes to.
private func decoded(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
}

final class SettingsTests: XCTestCase {
    func testTheDefaultsComeFromTheTuning() {
        let settings = Settings()

        XCTAssertEqual(settings.threshold.fraction, Tuning.claimThresholdDefault)
        XCTAssertEqual(settings.startingLives.get, Tuning.startingLives)
        XCTAssertEqual(settings.controlScheme, .stick)
        XCTAssertFalse(settings.leftHanded)
        XCTAssertEqual(settings.stickSize.get, StickSize.standard)
        XCTAssertEqual(settings.controlsOpacity.get, ControlsOpacity.standard)
        XCTAssertTrue(settings.haptics)
        XCTAssertFalse(settings.sounds)
        XCTAssertEqual(settings.rules, Rules())
    }

    func testTheRulesAreTheThresholdAndTheStartingLives() {
        let settings = edited()

        XCTAssertEqual(settings.rules, Rules(threshold: settings.threshold, startingLives: settings.startingLives))
    }

    func testTheOnlyControlSchemeIsTheStick() {
        XCTAssertEqual(ControlScheme.allCases, [.stick])
        XCTAssertEqual(ControlScheme.stick.title, "Stick")
    }

    func testAStickSizeInTheRangeIsKept() {
        for factor in [StickSize.range.lowerBound, StickSize.standard, StickSize.range.upperBound] {
            XCTAssertEqual(StickSize(factor).get, factor)
        }
    }

    func testAStickSizeOutsideTheRangeIsClampedIntoIt() {
        let (low, high) = (StickSize.range.lowerBound, StickSize.range.upperBound)

        XCTAssertEqual(StickSize(0).get, low)
        XCTAssertEqual(StickSize(-.infinity).get, low)
        XCTAssertEqual(StickSize(high + 1).get, high)
        XCTAssertEqual(StickSize(.infinity).get, high)
    }

    func testANaNStickSizeIsTheStandardOne() {
        XCTAssertEqual(StickSize(.nan), StickSize())
        XCTAssertEqual(StickSize().get, StickSize.standard)
    }

    func testAnOpacityInTheRangeIsKept() {
        for opacity in [ControlsOpacity.range.lowerBound, ControlsOpacity.standard, ControlsOpacity.range.upperBound] {
            XCTAssertEqual(ControlsOpacity(opacity).get, opacity)
        }
    }

    func testAnOpacityOutsideTheRangeIsClampedIntoIt() {
        let (low, high) = (ControlsOpacity.range.lowerBound, ControlsOpacity.range.upperBound)

        XCTAssertEqual(ControlsOpacity(0).get, low)
        XCTAssertEqual(ControlsOpacity(-1).get, low)
        XCTAssertEqual(ControlsOpacity(high + 1).get, high)
    }

    func testANaNOpacityIsTheStandardOne() {
        XCTAssertEqual(ControlsOpacity(.nan), ControlsOpacity())
        XCTAssertEqual(ControlsOpacity().get, ControlsOpacity.standard)
    }

    func testSettingsEncodeAndDecodeBackTheSame() throws {
        for settings in [Settings(), edited()] {
            let data = try JSONEncoder().encode(settings)

            XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: data), settings)
        }
    }

    func testAnEmptyValueDecodesAsTheDefaults() throws {
        XCTAssertEqual(try decoded("{}"), Settings())
    }

    func testMissingFieldsDecodeAsTheirDefaults() throws {
        XCTAssertEqual(
            try decoded(#"{"startingLives": \#(insideLives), "leftHanded": true}"#),
            Settings(startingLives: StartingLives(insideLives), leftHanded: true)
        )
    }

    func testANullFieldDecodesAsItsDefault() throws {
        XCTAssertEqual(try decoded(#"{"sounds": null, "haptics": false}"#), Settings(haptics: false))
    }

    func testAFieldThatDoesNotDecodeFailsTheWholeValue() {
        for json in [
            #"{"threshold": "high", "leftHanded": true}"#,
            #"{"controlScheme": "followTheFinger"}"#,
            #"{"haptics": "yes"}"#,
            #"{"stickSize": [1]}"#,
            "[]",
            "5",
        ] {
            XCTAssertThrowsError(try decoded(json), json) { error in
                XCTAssertTrue(error is DecodingError, "\(json): \(error)")
            }
        }
    }

    func testStoredValuesAboveTheirRangesAreClamped() throws {
        let settings = try decoded(#"{"threshold": 1.5, "startingLives": 99, "stickSize": 10, "controlsOpacity": 2}"#)

        XCTAssertEqual(settings.threshold.fraction, Tuning.claimThresholdRange.upperBound)
        XCTAssertEqual(settings.startingLives.get, Tuning.startingLivesRange.upperBound)
        XCTAssertEqual(settings.stickSize.get, StickSize.range.upperBound)
        XCTAssertEqual(settings.controlsOpacity.get, ControlsOpacity.range.upperBound)
    }

    func testStoredValuesBelowTheirRangesAreClamped() throws {
        let settings = try decoded(#"{"threshold": 0.1, "startingLives": 0, "stickSize": 0.1, "controlsOpacity": 0}"#)

        XCTAssertEqual(settings.threshold.fraction, Tuning.claimThresholdRange.lowerBound)
        XCTAssertEqual(settings.startingLives.get, Tuning.startingLivesRange.lowerBound)
        XCTAssertEqual(settings.stickSize.get, StickSize.range.lowerBound)
        XCTAssertEqual(settings.controlsOpacity.get, ControlsOpacity.range.lowerBound)
    }

    func testStoredFractionsPastFloatAreClampedAndKeepTheRest() throws {
        for (number, atUpperBound) in [(pastFloat, true), (belowFloat, false)] {
            let settings = try decoded(
                #"{"threshold": \#(number), "stickSize": \#(number), "controlsOpacity": \#(number), "sounds": true}"#
            )

            func bound(_ range: ClosedRange<Float>) -> Float {
                atUpperBound ? range.upperBound : range.lowerBound
            }
            XCTAssertEqual(settings.threshold.fraction, bound(Tuning.claimThresholdRange), number)
            XCTAssertEqual(settings.stickSize.get, bound(StickSize.range), number)
            XCTAssertEqual(settings.controlsOpacity.get, bound(ControlsOpacity.range), number)
            XCTAssertTrue(settings.sounds, number)
        }
    }

    func testAStoredFractionPastDoubleFailsTheWholeValue() {
        for number in [pastDouble, belowDouble] {
            for field in ["threshold", "stickSize", "controlsOpacity"] {
                let json = #"{"\#(field)": \#(number), "sounds": true}"#

                XCTAssertThrowsError(try decoded(json), json) { error in
                    XCTAssertTrue(error is DecodingError, "\(json): \(error)")
                }
            }
        }
    }

    func testStoredLivesOutsideUInt32AreClampedAndKeepTheRest() throws {
        for (lives, expected) in [
            ("-1", Tuning.startingLivesRange.lowerBound), ("4294967296", Tuning.startingLivesRange.upperBound),
        ] {
            let settings = try decoded(#"{"startingLives": \#(lives), "sounds": true}"#)

            XCTAssertEqual(settings.startingLives.get, expected, lives)
            XCTAssertTrue(settings.sounds, lives)
        }
    }
}

/// The settings as the sheet's steppers read and set them.
final class SettingsStepsTests: XCTestCase {
    func testTheRangesAreThoseOfTheValuesInPercentPoints() {
        XCTAssertEqual(Settings.thresholdPercents, thresholdPercents)
        XCTAssertEqual(Settings.stickSizePercents, stickSizePercents)
        XCTAssertEqual(Settings.opacityPercents, opacityPercents)
        XCTAssertEqual(Settings.startingLivesCounts, 1 ... Int(Tuning.maxLives))
    }

    func testTheStepsAreThoseOfTheSheet() {
        XCTAssertEqual(Settings.thresholdStep, thresholdStep)
        XCTAssertEqual(Settings.stickSizeStep, stickSizeStep)
        XCTAssertEqual(Settings.opacityStep, opacityStep)
    }

    func testEveryStepOfTheThresholdReadsBackAsSet() {
        var settings = Settings()
        for percent in stride(
            from: Settings.thresholdPercents.lowerBound, through: Settings.thresholdPercents.upperBound,
            by: Settings.thresholdStep
        ) {
            settings.thresholdPercent = percent

            XCTAssertEqual(settings.thresholdPercent, percent)
            XCTAssertEqual(settings.threshold, ClaimThreshold(Float(percent) / pointsPerUnit))
        }
    }

    func testTheDefaultsReadAsWholePercents() {
        let settings = Settings()

        XCTAssertEqual(settings.thresholdPercent, defaultThresholdPercent)
        XCTAssertEqual(settings.stickSizePercent, standardStickSizePercent)
        XCTAssertEqual(settings.opacityPercent, standardOpacityPercent)
        XCTAssertEqual(settings.startingLivesCount, Int(Tuning.startingLives))
    }

    func testValuesSetOutsideTheirRangesAreClamped() {
        var settings = Settings()

        settings.thresholdPercent = aboveThresholdPercent
        settings.stickSizePercent = belowStickSizePercent
        settings.opacityPercent = belowOpacityPercent
        settings.startingLivesCount = 0

        XCTAssertEqual(settings.thresholdPercent, Settings.thresholdPercents.upperBound)
        XCTAssertEqual(settings.stickSizePercent, Settings.stickSizePercents.lowerBound)
        XCTAssertEqual(settings.opacityPercent, Settings.opacityPercents.lowerBound)
        XCTAssertEqual(settings.startingLivesCount, Settings.startingLivesCounts.lowerBound)

        settings.startingLivesCount = Int.max

        XCTAssertEqual(settings.startingLivesCount, Settings.startingLivesCounts.upperBound)
    }

    func testValuesSetInTheirRangesAreKept() {
        var settings = Settings()

        settings.stickSizePercent = insideStickSizePercent
        settings.opacityPercent = insideOpacityPercent
        settings.startingLivesCount = Int(insideLives)

        XCTAssertEqual(settings.stickSize.get, insideStickSize)
        XCTAssertEqual(settings.controlsOpacity.get, insideOpacity)
        XCTAssertEqual(settings.startingLives.get, insideLives)
    }
}
