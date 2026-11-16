import Foundation
import XCTest
@testable import QixKit

/// The keys the values are stored under: a change would lose the stored ones.
private let highScoresKey = "highScores"
private let settingsKey = "settings"

/// Lives the stored settings of the tests start with, off the default.
private let storedLives: UInt32 = 5

/// Values under the keys that are not data, and data that is no stored value.
private let notData = "not data"
private let notJSON = Data("not json".utf8)

private func entry(_ name: String, _ score: UInt32) throws -> HighScore {
    try HighScore(name: Initials(name), score: score)
}

final class PersistTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "QixKitTests.Persist.\(name)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testWithNothingStoredTheTableIsEmptyAndTheSettingsTheDefaults() {
        XCTAssertEqual(Persist.loadHighScores(defaults), HighScores())
        XCTAssertEqual(Persist.loadSettings(defaults), Settings())
    }

    func testASavedTableLoadsBackTheSameUnderItsKey() throws {
        let table = try HighScores([entry("QIX", 900), entry("ABC", 10)])

        Persist.saveHighScores(table, to: defaults)

        XCTAssertEqual(Persist.highScoresKey, highScoresKey)
        XCTAssertNotNil(defaults.data(forKey: highScoresKey))
        XCTAssertEqual(Persist.loadHighScores(defaults), table)
    }

    func testSavedSettingsLoadBackTheSameUnderTheirKey() {
        let settings = Settings(startingLives: StartingLives(storedLives), leftHanded: true, sounds: true)

        Persist.saveSettings(settings, to: defaults)

        XCTAssertEqual(Persist.settingsKey, settingsKey)
        XCTAssertNotNil(defaults.data(forKey: settingsKey))
        XCTAssertEqual(Persist.loadSettings(defaults), settings)
    }

    func testASaveReplacesTheValueStored() throws {
        Persist.saveSettings(Settings(leftHanded: true), to: defaults)
        Persist.saveHighScores(try HighScores([entry("OLD", 1)]), to: defaults)
        let table = try HighScores([entry("NEW", 2)])

        Persist.saveSettings(Settings(), to: defaults)
        Persist.saveHighScores(table, to: defaults)

        XCTAssertEqual(Persist.loadSettings(defaults), Settings())
        XCTAssertEqual(Persist.loadHighScores(defaults), table)
    }

    func testValuesThatAreNotDataLoadAsAnEmptyTableAndTheDefaults() {
        defaults.set(notData, forKey: highScoresKey)
        defaults.set(notData, forKey: settingsKey)

        XCTAssertEqual(Persist.loadHighScores(defaults), HighScores())
        XCTAssertEqual(Persist.loadSettings(defaults), Settings())
    }

    func testDataThatDoesNotDecodeLoadsAsAnEmptyTableAndTheDefaults() {
        for data in [notJSON, Data(#"{"threshold": "high", "leftHanded": true}"#.utf8)] {
            defaults.set(data, forKey: highScoresKey)
            defaults.set(data, forKey: settingsKey)

            XCTAssertEqual(Persist.loadHighScores(defaults), HighScores())
            XCTAssertEqual(Persist.loadSettings(defaults), Settings())
        }
    }

    func testStoredSettingsMissingFieldsLoadTheirDefaults() {
        defaults.set(Data(#"{"startingLives": \#(storedLives)}"#.utf8), forKey: settingsKey)

        XCTAssertEqual(Persist.loadSettings(defaults), Settings(startingLives: StartingLives(storedLives)))
    }

    func testAStoredTableKeepsItsValidEntries() throws {
        let json = #"[{"name": "QIX", "score": 900}, {"name": "bad", "score": 5}, null]"#
        defaults.set(Data(json.utf8), forKey: highScoresKey)

        XCTAssertEqual(Persist.loadHighScores(defaults).entries, [try entry("QIX", 900)])
    }
}
