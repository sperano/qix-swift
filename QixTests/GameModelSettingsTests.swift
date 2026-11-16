import Foundation
import QixKit
import XCTest
@testable import Qix

/// One frame at the tick rate: one tick.
private let frame: TimeInterval = 1.0 / Double(Tuning.tickHz)

/// The clock a model's game is seeded from.
private let launch = Date(timeIntervalSince1970: 1)

/// Lives the edited settings start a game with, off the default.
private let editedLives: UInt32 = 5

/// Frames the tests that expect nothing to happen run.
private let idleFrames: UInt32 = 10

/// Where the stick's thumb lands.
private let stickPoint = CGPoint(x: 60, y: 200)

/// Where the Slow button's thumb lands.
private let slowPoint = CGPoint(x: 800, y: 200)

/// A stand-in for a `UITouch`: only its identity counts.
private final class Finger: Sendable {}

private let finger = Finger()

/// Data under the high scores' key that a save would replace.
private let sentinel = Data("sentinel".utf8)

/// The tests of the settings in the model: loaded at launch, saved and applied on each edit, and
/// the sheet, which holds the game.
@MainActor
final class GameModelSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var model: GameModel!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "QixTests.GameModelSettings.\(name)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        model = GameModel(defaults: defaults, seededAt: launch)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    private func frames(_ count: UInt32) {
        for _ in 0 ..< count {
            model.advance(by: frame, pad: nil)
        }
    }

    private func table() throws -> HighScores {
        try HighScores([HighScore(name: Initials("QIX"), score: 900), HighScore(name: Initials("ABC"), score: 10)])
    }

    func testWithNothingStoredTheModelStartsFromTheDefaults() {
        XCTAssertEqual(model.settings, Settings())
        XCTAssertEqual(model.session.highScores, HighScores())
        XCTAssertEqual(model.session.game.lives, Tuning.startingLives)
    }

    func testANewModelLoadsTheStoredSettingsAndHighScores() throws {
        let settings = Settings(startingLives: StartingLives(editedLives), leftHanded: true)
        Persist.saveSettings(settings, to: defaults)
        Persist.saveHighScores(try table(), to: defaults)

        model = GameModel(defaults: defaults, seededAt: launch)

        XCTAssertEqual(model.settings, settings)
        XCTAssertEqual(model.scene.settings, settings)
        XCTAssertEqual(model.session.game.lives, editedLives)
        XCTAssertEqual(model.session.highScores, try table())
        XCTAssertEqual(model.scene.screen, .title(try table()))
    }

    func testAnEditIsSavedAtOnceAndAppliesToTheTitlesGame() {
        model.settings.startingLivesCount = Int(editedLives)

        XCTAssertEqual(Persist.loadSettings(defaults).startingLives, StartingLives(editedLives))
        XCTAssertEqual(model.session.game.lives, editedLives)
    }

    func testAnEditOutsideTheRulesIsSavedAtOnce() {
        model.settings.leftHanded = true
        model.settings.opacityPercent = Settings.opacityPercents.lowerBound

        XCTAssertEqual(Persist.loadSettings(defaults), model.settings)
        XCTAssertTrue(Persist.loadSettings(defaults).leftHanded)
        XCTAssertEqual(Persist.loadSettings(defaults).controlsOpacity.get, ControlsOpacity.range.lowerBound)
    }

    func testAnEditDuringAGameAppliesToTheNextOne() {
        model.tap()
        frames(1)

        model.settings.startingLivesCount = Int(editedLives)

        XCTAssertEqual(model.session.game.lives, Tuning.startingLives)
        XCTAssertEqual(model.session.game.rules.startingLives, StartingLives(editedLives))
    }

    func testTheTableIsSavedOnlyWhenItChanges() throws {
        Persist.saveHighScores(try table(), to: defaults)
        model = GameModel(defaults: defaults, seededAt: launch)
        defaults.set(sentinel, forKey: Persist.highScoresKey)

        model.tap()
        frames(idleFrames)

        XCTAssertEqual(defaults.data(forKey: Persist.highScoresKey), sentinel)
    }

    func testTheSettingsButtonOpensTheSettingsAndHoldsTheGame() {
        model.openSettings()

        XCTAssertTrue(model.isShowingSettings)
        XCTAssertTrue(model.isOnHold)
        XCTAssertTrue(model.loop.isInterrupted)
    }

    func testATapWhileTheSettingsAreOpenDoesNotStartTheGame() {
        model.openSettings()
        model.tap()
        frames(1)

        model.isShowingSettings = false
        frames(1)

        XCTAssertEqual(model.session.state, .title)
        XCTAssertFalse(model.isOnHold)
        model.tap()
        frames(1)
        XCTAssertEqual(model.session.state, .playing)
    }

    func testKeysAndTouchesWhileTheSettingsAreOpenReachNothing() {
        model.openSettings()

        model.keyDown(.left)
        model.touch(.began(touch: ObjectIdentifier(finger), on: .stick, at: stickPoint))

        XCTAssertEqual(model.loop.controls.held, [])
        XCTAssertEqual(model.touches, TouchControls())
    }

    func testOpeningTheSettingsLetsGoOfTheTouchesHeld() {
        model.touch(.began(touch: ObjectIdentifier(finger), on: .slow, at: slowPoint))
        XCTAssertNotEqual(model.touches, TouchControls())
        XCTAssertEqual(model.loop.controls.held, [.slow])

        model.openSettings()

        XCTAssertEqual(model.touches, TouchControls())
        XCTAssertEqual(model.loop.controls.held, [])
    }

    func testTheSettingsOpenFromTheTitleOnly() {
        model.tap()
        frames(1)

        model.openSettings()

        XCTAssertFalse(model.isShowingSettings)
        XCTAssertFalse(model.isOnHold)
        XCTAssertEqual(model.session.state, .playing)
    }
}
