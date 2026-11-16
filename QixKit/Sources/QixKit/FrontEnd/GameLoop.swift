// The session the app plays, advanced frame by frame: qix-rs's `QixApp::advance` and `tick`
// (`crates/qix/src/app.rs`), without the attract demo yet, and with the iPhone's initials typed in a
// text field and its haptics.

/// A `Session` with the controls that steer it and the clock that ticks it: each frame samples
/// the controls through an `InputLatch` and runs the ticks a `FixedTimestep` owes, so a press is
/// neither lost nor doubled at any frame rate. A finger aiming on the board (`steering`) steers
/// in play when no other control holds a direction, afresh at each tick, drawing fast unless slow
/// is held: drawing B, as with the stick.
///
/// The loop is on hold, and runs no tick, while the settings are open over it (`interrupt`) and
/// while the initials of a high score are typed (`enterInitials`): the controls do not act on
/// the game behind a sheet or a text field.
///
/// Each tick queues the sounds of the session's events (`Sound.sounds`) and its haptic
/// (`HapticCues`), which the front end takes once a frame (`takeSounds`, `takeHaptics`).
public struct GameLoop: Sendable {
    /// The session played.
    public private(set) var session: Session
    /// The keyboard's, the game pad's and the touch screen's controls, and the taps.
    public var controls = Controls()
    /// The follow-the-finger steering, aimed by the board's touch.
    public var steering = TouchSteering()
    /// Something is open over the game: see `interrupt`.
    public private(set) var isInterrupted = false
    /// The sounds the ticks raised since `takeSounds` last took them, in order.
    public private(set) var sounds: [Sound] = []
    /// The haptics the ticks raised since `takeHaptics` last took them, in order: one a tick at
    /// most.
    public private(set) var haptics: [Haptic] = []
    private var cues = HapticCues()
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
            tick(steered(latch.nextTick()))
        }
        return ticks
    }

    /// Empties the queue of sounds and returns what it held.
    public mutating func takeSounds() -> [Sound] {
        defer { sounds = [] }
        return sounds
    }

    /// Empties the queue of haptics and returns what it held.
    public mutating func takeHaptics() -> [Haptic] {
        defer { haptics = [] }
        return haptics
    }

    /// Ticks the session with `input` and queues the tick's sounds and haptic.
    private mutating func tick(_ input: InputState) {
        let marker = session.game.marker
        session.tick(input)
        sounds += Sound.sounds(session.events)
        if let haptic = cues.cue(input, from: marker, to: session) {
            haptics.append(haptic)
        }
    }

    /// `input` with the steering's direction this tick, in play when `input` holds none.
    private mutating func steered(_ input: InputState) -> InputState {
        guard session.state == .playing, input.dir == nil, let dir = steering.dir(session.game) else {
            return input
        }
        var input = input
        input.dir = dir
        input.fast = input.fast || !input.slow
        return input
    }

    /// The app leaves the foreground: a game in play pauses at once, without a tick of play, and
    /// every key and touch control held, the steering's aim and every press not yet delivered are
    /// dropped, so nothing acts on the return. The game pad is polled again on the next frame.
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

    /// Drops every key and touch control held, the steering's aim and every press not yet
    /// delivered.
    private mutating func releaseControls() {
        controls.releaseKeys()
        controls.setTouch([])
        steering = TouchSteering()
        controls.dropPresses()
        latch = InputLatch()
    }
}
