// The session the app plays, advanced frame by frame: qix-rs's `QixApp::advance` and `tick`
// (`crates/qix/src/app.rs`), without the settings, the sounds and the attract demo yet.

/// A `Session` with the controls that steer it and the clock that ticks it: each frame samples
/// the controls through an `InputLatch` and runs the ticks a `FixedTimestep` owes, so a press is
/// neither lost nor doubled at any frame rate.
public struct GameLoop: Sendable {
    /// The session played.
    public private(set) var session: Session
    /// The keyboard's and the game pad's controls, and the taps.
    public var controls = Controls()
    private var timestep = FixedTimestep()
    private var latch = InputLatch()

    /// A loop playing `session`, nothing held.
    public init(session: Session) {
        self.session = session
    }

    /// Samples the controls and runs as many ticks as a frame of `dt` seconds owes; returns how
    /// many ran.
    @discardableResult
    public mutating func advance(_ dt: Float) -> UInt32 {
        latch.record(controls.sample())
        let ticks = timestep.advance(dt)
        for _ in 0 ..< ticks {
            session.tick(latch.nextTick())
        }
        return ticks
    }

    /// The app leaves the foreground: a game in play pauses at once, without a tick of play, and
    /// every key held and press not yet delivered is dropped, so nothing acts on the return. The
    /// game pad is polled again on the next frame.
    public mutating func suspend() {
        controls.releaseKeys()
        controls.dropPresses()
        latch = InputLatch()
        if session.state == .playing {
            session.tick(InputState(pause: true))
        }
    }
}
