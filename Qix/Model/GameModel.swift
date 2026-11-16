import Foundation
import Observation
import QixKit

/// The game the app plays, the only thing the views read: a `GameLoop` over a `Session`, fed by the
/// display link's frames, the keyboard, the game pad, the touch controls and the taps, what is
/// drawn of the board shown (the attract demo's while one plays), redrawn only when the board
/// changes, and the settings. The settings and the
/// high score table are kept in `UserDefaults` (`Persist`), each saved as soon as it changes. Each
/// frame plays the haptics and the sounds its ticks queued, as the settings allow.
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
    /// The touch controls, as the touches on their zones hold them.
    private(set) var touches = TouchControls<ObjectIdentifier>()
    /// Where the settings and the high scores are kept; nowhere when nil.
    private let defaults: UserDefaults?
    /// The high score table as last saved.
    @ObservationIgnored private var savedHighScores: HighScores
    /// What the player feels, while `Settings.haptics` is on.
    private let hapticPlayer: any HapticPlayer
    /// What the player hears, while `Settings.sounds` is on.
    private let soundPlayer: any SoundPlayer

    /// The settings: an edit is saved at once and its rules apply to the next game.
    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            if settings.rules != oldValue.rules {
                loop.setRules(settings.rules)
            }
            if let defaults {
                Persist.saveSettings(settings, to: defaults)
            }
        }
    }

    /// The settings sheet is open: the loop is interrupted (`GameLoop.interrupt`) until it closes.
    var isShowingSettings = false {
        didSet {
            guard isShowingSettings != oldValue else { return }
            if isShowingSettings {
                touches = TouchControls()
                loop.interrupt()
            } else {
                loop.resume()
            }
        }
    }

    /// A model playing `session` with `settings`, keeping them and the high scores in `defaults`,
    /// or nowhere, and playing its haptics and sounds on `haptics` and `sounds`. A session not
    /// playing by the settings' rules is given them (`Session.setRules`).
    init(
        session: Session, settings: Settings = Settings(), defaults: UserDefaults? = nil,
        haptics: any HapticPlayer = SilentHaptics(), sounds: any SoundPlayer = SilentSounds()
    ) {
        var session = session
        if session.game.rules != settings.rules {
            session.setRules(settings.rules)
        }
        let loop = GameLoop(session: session)
        self.loop = loop
        board = BoardImage(loop.shownGame.board)
        savedHighScores = session.highScores
        self.settings = settings
        self.defaults = defaults
        hapticPlayer = haptics
        soundPlayer = sounds
    }

    /// A model on the title screen of a new game seeded from `date`, so each launch plays
    /// differently, with the settings and the high score table kept in `defaults`, playing its
    /// haptics and sounds on `haptics` and `sounds`.
    convenience init(
        defaults: UserDefaults, seededAt date: Date = .now,
        haptics: any HapticPlayer = SilentHaptics(), sounds: any SoundPlayer = SilentSounds()
    ) {
        let game = Game(rng: Rng(seed: Self.seed(at: date)))
        self.init(
            session: Session(game: game, highScores: Persist.loadHighScores(defaults)),
            settings: Persist.loadSettings(defaults), defaults: defaults, haptics: haptics, sounds: sounds
        )
    }

    var session: Session {
        loop.session
    }

    /// Everything the frame draws.
    var scene: PlayfieldScene {
        PlayfieldScene(loop: loop, board: board, touches: touches, settings: settings)
    }

    /// The screen is to stay awake: a game is in play.
    var keepsScreenAwake: Bool {
        session.state == .playing
    }

    /// The controls do not act on the game: the settings are open or the initials are being typed
    /// (`GameLoop.isOnHold`).
    var isOnHold: Bool {
        loop.isOnHold
    }

    /// Runs a frame of `dt` seconds with the game pad as polled, `nil` without one, plays its
    /// haptics and sounds, then redraws the board shown if it changed and saves the high score table if
    /// it did.
    func advance(by dt: TimeInterval, pad: PadState?) {
        loop.controls.setPad(pad?.controls ?? [])
        loop.advance(Float(dt))
        playFeedback()
        if board.board != loop.shownGame.board {
            board = BoardImage(loop.shownGame.board)
        }
        saveHighScoresIfChanged()
    }

    /// The key of `control` went down; ignored on hold.
    func keyDown(_ control: Control) {
        guard !isOnHold else { return }
        loop.controls.keyDown(control)
    }

    func keyUp(_ control: Control) {
        loop.controls.keyUp(control)
    }

    /// Every key went up: the keyboard's presses were cancelled.
    func releaseKeys() {
        loop.controls.releaseKeys()
    }

    /// A touch on a touch control's zone: the controls the touches hold and the board's aim go to
    /// the loop at once, to be sampled on the next frame, and a tap on the board's zone out of play
    /// confirms (`tap`) once it lifts, not when it is cancelled. A touch landing stops the attract
    /// demo (`GameLoop.touchDown`); one landing on hold is ignored.
    func touch(_ event: TouchEvent) {
        switch event {
        case let .began(touch, on: control, at: point):
            guard !isOnHold else { return }
            loop.touchDown()
            touches.began(touch, on: control, at: Vec2(point), inPlay: session.state == .playing)
        case let .moved(touch, to: point): touches.moved(touch, to: Vec2(point))
        case let .ended(touch):
            if touches.ended(touch) {
                tap()
            }
        case let .cancelled(touch): touches.cancelled(touch)
        }
        loop.controls.setTouch(touches.held)
        loop.steering.steer(towards: touches.aim)
    }

    /// A tap on the screen: confirm, to start or continue; ignored on hold.
    func tap() {
        guard !isOnHold else { return }
        loop.controls.press(.confirm)
    }

    /// The HUD's pause button: pause, or resume; ignored on hold.
    func pressPause() {
        guard !isOnHold else { return }
        loop.controls.press(.pause)
    }

    /// The title screen's settings button: opens the settings, on the title screen only.
    func openSettings() {
        guard session.state == .title else { return }
        isShowingSettings = true
    }

    /// The initials typed in the initials field: when they are initials (`InitialsField`) and the
    /// session waits for them, the score goes into the table, which is saved, and the title screen
    /// shows. Returns whether they were taken.
    @discardableResult
    func enterInitials(_ text: String) -> Bool {
        guard let initials = InitialsField.initials(text), loop.enterInitials(initials) != nil else { return false }
        touches = TouchControls()
        saveHighScoresIfChanged()
        return true
    }

    /// The app left the foreground: see `GameLoop.suspend`. The touches held let go of their
    /// controls; a thumb still down steers again once it touches anew.
    func suspend() {
        touches = TouchControls()
        loop.suspend()
    }

    /// Takes the haptics and the sounds the loop queued and plays those the settings allow: a
    /// sound queued while sounds are off is dropped, never played once they are on.
    private func playFeedback() {
        let haptics = loop.takeHaptics()
        let sounds = loop.takeSounds()
        if settings.haptics {
            for haptic in haptics {
                hapticPlayer.play(haptic)
            }
        }
        if settings.sounds {
            for sound in sounds {
                soundPlayer.play(sound)
            }
        }
    }

    /// Saves the high score table when it differs from the one saved last.
    private func saveHighScoresIfChanged() {
        guard session.highScores != savedHighScores else { return }
        savedHighScores = session.highScores
        if let defaults {
            Persist.saveHighScores(savedHighScores, to: defaults)
        }
    }

    /// The nanoseconds from the Unix epoch to `date`, as qix-rs seeds a game; zero before the epoch
    /// or past what 64 bits hold.
    nonisolated static func seed(at date: Date) -> UInt64 {
        let nanoseconds = (date.timeIntervalSince1970 * nanosecondsPerSecond).rounded(.down)
        return UInt64(exactly: nanoseconds) ?? 0
    }
}
