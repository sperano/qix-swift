import Foundation
import Observation
import QixKit

/// The game the app plays, the only thing the views read: a `GameLoop` over a `Session`, fed by the
/// display link's frames, the keyboard, the game pad and the taps, and what is drawn of its board,
/// redrawn only when the board changes.
@MainActor
@Observable
final class GameModel {
    /// Nanoseconds in a second, to seed a game from the clock.
    nonisolated static let nanosecondsPerSecond: Double = 1e9

    /// The loop playing the session.
    private(set) var loop: GameLoop
    /// What is drawn of the board shown, from the last frame whose board differed from the one
    /// before.
    private(set) var board: BoardImage

    /// A model playing `session`.
    init(session: Session) {
        loop = GameLoop(session: session)
        board = BoardImage(session.game.board)
    }

    /// A model on the title screen of a new game seeded from `date`, so each launch plays
    /// differently, with an empty high score table.
    convenience init(seededAt date: Date = .now) {
        self.init(session: Session(game: Game(rng: Rng(seed: Self.seed(at: date)))))
    }

    var session: Session {
        loop.session
    }

    /// Everything the frame draws.
    var scene: PlayfieldScene {
        PlayfieldScene(session: session, board: board)
    }

    /// The screen is to stay awake: a game is in play.
    var keepsScreenAwake: Bool {
        session.state == .playing
    }

    /// Runs a frame of `dt` seconds with the game pad as polled, `nil` without one, then redraws the
    /// board if it changed.
    func advance(by dt: TimeInterval, pad: PadState?) {
        loop.controls.setPad(pad?.controls ?? [])
        loop.advance(Float(dt))
        if board.board != session.game.board {
            board = BoardImage(session.game.board)
        }
    }

    func keyDown(_ control: Control) {
        loop.controls.keyDown(control)
    }

    func keyUp(_ control: Control) {
        loop.controls.keyUp(control)
    }

    /// Every key went up: the keyboard's presses were cancelled.
    func releaseKeys() {
        loop.controls.releaseKeys()
    }

    /// A tap on the screen: confirm, to start or continue.
    func tap() {
        loop.controls.press(.confirm)
    }

    /// The HUD's pause button: pause, or resume.
    func pressPause() {
        loop.controls.press(.pause)
    }

    /// The app left the foreground: see `GameLoop.suspend`.
    func suspend() {
        loop.suspend()
    }

    /// The nanoseconds from the Unix epoch to `date`, as qix-rs seeds a game; zero before the epoch
    /// or past what 64 bits hold.
    nonisolated static func seed(at date: Date) -> UInt64 {
        let nanoseconds = (date.timeIntervalSince1970 * nanosecondsPerSecond).rounded(.down)
        return UInt64(exactly: nanoseconds) ?? 0
    }
}
