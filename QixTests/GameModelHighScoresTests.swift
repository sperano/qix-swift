import Foundation
import QixKit
import XCTest
@testable import Qix

/// One frame at the tick rate: one tick.
private let frame: TimeInterval = 1.0 / Double(Tuning.tickHz)

/// Seed of the game the tests play.
private let gameSeed: UInt64 = 1_206

/// The board of `levelGame`: a stix up its middle column from the marker's start claims the cells
/// right of it, leaving the Qix in cell (0, 0) on its left. QixKit's `StateTests.levelGame`.
private let boardWidth: UInt16 = 8
private let boardHeight: UInt16 = 3

/// Cells `levelGame` claims before the stix, clear of its column and of the top row.
private let claimedBefore: [(UInt16, UInt16)] = [(0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2)]

/// The claim threshold of `levelGame`, which its stix passes.
private let lowThreshold: Float = 0.5

/// The ends of a still Qix across the middle of cell (0, 0).
private let qixLeft = Vec2(x: 0.25, y: 0.5)
private let qixRight = Vec2(x: 0.75, y: 0.5)

/// Frames the Sparx of the second level are given to take every life: far more than their laps
/// of the small border need.
private let maxFrames = 10_000

/// Frames the tests that expect nothing to happen run.
private let idleFrames: UInt32 = 10

/// The initials the tests type, as typed and as entered.
private let typed = "q1i x"
private let typedName = "QIX"

/// A game whose first level a stix up from the marker completes, with points, and whose second
/// level's Sparx then take every life.
private func levelGame() -> Game {
    var board = Board(width: boardWidth, height: boardHeight)
    for (x, y) in claimedBefore {
        board.setCell(x: x, y: y, to: .claimed(.fast))
    }
    let qix = QixKit.Qix(a: qixLeft, b: qixRight, vel: Vec2(), spin: 0)
    var game = Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
    game.setClaimThreshold(ClaimThreshold(lowThreshold))
    return game
}

/// The qualifying flow in the model: a game over that makes the table asks for initials in the
/// field, holding the game, and the initials typed go into the table, which is saved.
@MainActor
final class GameModelHighScoresTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var model: GameModel!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "QixTests.GameModelHighScores.\(name)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        model = GameModel(session: Session(game: levelGame()), defaults: defaults)
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

    /// Taps and runs a frame.
    private func confirm() {
        model.tap()
        frames(1)
    }

    /// Plays the game to its game over: the stix completing the first level, then idle until the
    /// Sparx of the second take every life.
    private func playToGameOver(file: StaticString = #filePath, line: UInt = #line) {
        confirm()
        model.keyDown(.fast)
        model.keyDown(.up)
        frames(UInt32(boardHeight) * Tuning.markerStepTicks)
        model.keyUp(.up)
        model.keyUp(.fast)
        guard case .levelComplete = model.session.state else {
            return XCTFail("the level is not complete: \(model.session.state)", file: file, line: line)
        }
        confirm()
        for _ in 0 ..< maxFrames where model.session.state != .gameOver {
            frames(1)
        }
        XCTAssertEqual(model.session.state, .gameOver, file: file, line: line)
        XCTAssertGreaterThan(model.session.game.score.points, 0, "no points", file: file, line: line)
    }

    /// Plays to the game over and confirms it: the field asks for initials.
    private func playToEntry(file: StaticString = #filePath, line: UInt = #line) {
        playToGameOver(file: file, line: line)
        confirm()
        XCTAssertTrue(model.loop.isEnteringInitials, "\(model.session.state)", file: file, line: line)
    }

    func testAQualifyingGameOverAsksForInitialsInTheFieldAndHoldsTheGame() {
        playToEntry()

        let scene = model.scene
        XCTAssertNil(scene.screen)
        XCTAssertEqual(scene.initialsPrompt, .highScoreEntry(model.session.game, model.session.highScores))
        XCTAssertNil(scene.hudButton)
        XCTAssertTrue(model.isOnHold)
        XCTAssertFalse(model.isShowingSettings)
    }

    func testTapsAndKeysDuringTheEntryDoNotActOnIt() {
        playToEntry()
        let session = model.session

        model.keyDown(.up)
        for _ in 0 ..< Tuning.initialsLen {
            confirm()
        }
        frames(idleFrames)

        XCTAssertEqual(model.session.state, session.state)
        XCTAssertEqual(model.session.highScores, session.highScores)
        XCTAssertEqual(model.loop.controls.held, [])
    }

    func testTheTypedInitialsGoIntoTheTableWhichIsSaved() throws {
        playToEntry()
        let points = model.session.game.score.points

        XCTAssertTrue(model.enterInitials(typed))

        let expected = try HighScores([HighScore(name: Initials(typedName), score: points)])
        XCTAssertEqual(model.session.state, .title)
        XCTAssertEqual(model.session.highScores, expected)
        XCTAssertEqual(Persist.loadHighScores(defaults), expected)
        XCTAssertFalse(model.isOnHold)
        XCTAssertEqual(model.scene.screen, .title(expected))
        XCTAssertNil(model.scene.initialsPrompt)
    }

    func testTooFewLettersAreRefusedAndNothingIsSaved() {
        playToEntry()

        XCTAssertFalse(model.enterInitials("a1"))

        XCTAssertTrue(model.loop.isEnteringInitials)
        XCTAssertEqual(model.session.highScores, HighScores())
        XCTAssertNil(defaults.data(forKey: Persist.highScoresKey))
    }

    func testInitialsOutsideTheEntryAreRefused() {
        XCTAssertFalse(model.enterInitials(typedName))

        XCTAssertEqual(model.session.state, .title)
        XCTAssertNil(defaults.data(forKey: Persist.highScoresKey))
    }

    func testAGameOverOffTheTableSkipsTheEntryAndSavesNothing() throws {
        let unbeatable = try HighScores(
            Array(repeating: HighScore(name: Initials("TOP"), score: .max), count: Tuning.highScoreCount)
        )
        model = GameModel(session: Session(game: levelGame(), highScores: unbeatable), defaults: defaults)
        playToGameOver()

        confirm()

        XCTAssertEqual(model.session.state, .title)
        XCTAssertNil(defaults.data(forKey: Persist.highScoresKey))
    }
}
