import QixKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Qix

/// The playfield of each state of a session, on the host window (the iPhone 17) and on the
/// smallest landscape iPhone: the board, its enemies, the HUD and the screen over the board.
final class PlayfieldSnapshotTests: SnapshotTestCase {
    /// The reference name of the small phone's images.
    private static let smallName = "small"

    /// The claim a level-complete screen shows, the split's and the bonus.
    private static let levelFraction: Float = 0.8125
    private static let levelBonus: UInt32 = 6_000

    /// Asserts `scene` on both phones.
    private func assertScene(_ scene: PlayfieldScene, testName: String = #function, line: UInt = #line) throws {
        try assertScreen(PlayfieldView(scene: scene), testName: testName, line: line)
        try assertScreen(
            PlayfieldView(scene: scene), on: Self.smallPhone, named: Self.smallName, testName: testName, line: line
        )
    }

    /// The scene of `session`.
    private func scene(_ session: Session) -> PlayfieldScene {
        PlayfieldScene(session: session, board: BoardImage(session.game.board))
    }

    /// The board in play, with `screen` over it and no pause button.
    private func inPlay(with screen: Screen) -> PlayfieldScene {
        let session = PlayfieldFixtures.inPlay()
        return PlayfieldScene(
            game: session.game, board: BoardImage(session.game.board),
            hud: Hud(game: session.game, highScore: session.highScore), screen: screen, pauseButton: nil
        )
    }

    func testTheTitleScreenWithAFullHighScoreTable() throws {
        let session = Session(
            game: Game(rng: Rng(seed: PlayfieldFixtures.seed)),
            highScores: PlayfieldFixtures.fullHighScores
        )

        try assertScene(scene(session))
    }

    /// A claim, a stix drawn slow then fast with its fuse lit, the Qix, the Sparx and the HUD.
    func testABoardInPlay() throws {
        let session = PlayfieldFixtures.inPlay()
        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.game.lives, Tuning.startingLives, "the script lost a life")
        XCTAssertEqual(session.game.stix?.kinds, [.slow, .fast])
        XCTAssertEqual(session.game.fuse, Fuse(pos: 1))
        XCTAssertGreaterThan(session.game.board.claimedFraction(), 0)

        try assertScene(scene(session))
    }

    func testThePauseScreen() throws {
        let session = PlayfieldFixtures.paused()
        XCTAssertEqual(session.state, .paused)

        try assertScene(scene(session))
    }

    func testALevelCompleteScreenAfterASplit() throws {
        let game = PlayfieldFixtures.inPlay().game
        let screen = Screen.levelComplete(game, fraction: Self.levelFraction, bonus: Self.levelBonus, split: true)

        try assertScene(inPlay(with: screen))
    }

    func testTheGameOverScreenOfANewHighScore() throws {
        try assertScene(inPlay(with: .gameOver(PlayfieldFixtures.inPlay().game, HighScores())))
    }

    func testTheHighScoreEntryScreen() throws {
        let game = PlayfieldFixtures.inPlay().game
        let screen = Screen.highScoreEntry(game, PlayfieldFixtures.highScores, InitialsEntry())

        try assertScene(inPlay(with: screen))
    }

    /// Every HUD value at its widest, the lives past the markers shown, the multiplier and the
    /// pause button: each stays in its column.
    func testTheWidestHud() throws {
        let session = PlayfieldFixtures.inPlay()
        let scene = PlayfieldScene(
            game: session.game, board: BoardImage(session.game.board), hud: PlayfieldFixtures.widestHud,
            screen: nil, pauseButton: .pause
        )

        try assertScene(scene)
    }
}
