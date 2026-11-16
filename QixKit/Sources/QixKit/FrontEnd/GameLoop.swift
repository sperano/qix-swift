// The session the app plays, advanced frame by frame: qix-rs's `QixApp::advance` and `tick`
// (`crates/qix/src/app.rs`), without the sounds and the attract demo yet, and with the iPhone's
// initials typed in a text field.

/// A `Session` with the controls that steer it and the clock that ticks it: each frame samples
/// the controls through an `InputLatch` and runs the ticks a `FixedTimestep` owes, so a press is
/// neither lost nor doubled at any frame rate.
///
/// The loop is on hold, and runs no tick, while the settings are open over it (`interrupt`) and
/// while the initials of a high score are typed (`enterInitials`): the controls do not act on
/// the game behind a sheet or a text field.
public struct GameLoop: Sendable {
    /// The session played.
    public private(set) var session: Session
    /// The keyboard's, the game pad's and the touch screen's controls, and the taps.
    public var controls = Controls()
    /// Something is open over the game: see `interrupt`.
    public private(set) var isInterrupted = false
    private var timestep = FixedTimestep()
    private var latch = InputLatch()

    /// A loop playing `session`, nothing held.
    public init(session: Session) {
        self.session = session
    }

    /// The session waits for the initials of a high score, which `enterInitials` types: its
    /// `InitialsEntry` takes no tick of the controls.
    public var isEnteringInitials: Bool {
        if case .highScoreEntry = session.state {
            return true
        }
        return false
    }

    /// No tick runs: the loop is interrupted or the initials are being typed.
    public var isOnHold: Bool {
        isInterrupted || isEnteringInitials
    }

    /// Samples the controls and runs as many ticks as a frame of `dt` seconds owes; returns how
    /// many ran. On hold, it runs none and drops the presses, so none acts once the hold ends.
    @discardableResult
    public mutating func advance(_ dt: Float) -> UInt32 {
        guard !isOnHold else {
            controls.dropPresses()
            return 0
        }
        latch.record(controls.sample())
        let ticks = timestep.advance(dt)
        for _ in 0 ..< ticks {
            session.tick(latch.nextTick())
        }
        return ticks
    }

    /// The app leaves the foreground: a game in play pauses at once, without a tick of play, and
    /// every key and touch control held and press not yet delivered is dropped, so nothing acts on
    /// the return. The game pad is polled again on the next frame.
    public mutating func suspend() {
        releaseControls()
        if session.state == .playing {
            session.tick(InputState(pause: true))
        }
    }

    /// The settings open over the game: it is suspended (see `suspend`) and the loop is on hold
    /// until `resume`.
    public mutating func interrupt() {
        suspend()
        isInterrupted = true
    }

    /// The settings closed: the loop runs again, with no key, touch or press of the interruption.
    public mutating func resume() {
        isInterrupted = false
        releaseControls()
    }

    /// Sets the rules of the games to come: `Session.setRules`.
    public mutating func setRules(_ rules: Rules) {
        session.setRules(rules)
    }

    /// The initials typed for the high score: `Session.enterInitials`, after which the title
    /// screen runs with no key, touch or press of the typing. Returns the score's rank, nil when
    /// the session was not waiting for initials.
    @discardableResult
    public mutating func enterInitials(_ name: Initials) -> Int? {
        let rank = session.enterInitials(name)
        if rank != nil {
            releaseControls()
        }
        return rank
    }

    /// Drops every key and touch control held and every press not yet delivered.
    private mutating func releaseControls() {
        controls.releaseKeys()
        controls.setTouch([])
        controls.dropPresses()
        latch = InputLatch()
    }
}
