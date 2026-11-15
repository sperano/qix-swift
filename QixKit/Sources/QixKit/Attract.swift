// Attract mode: the title screen starts a demo after sitting idle.

/// Counts the idle ticks of the title screen and runs the `Demo` once there are
/// `Tuning.attractDelayTicks` of them.
public struct Attract: Sendable {
    /// Ticks since the last input, or the end of the last demo.
    private var idleTicks: UInt32
    /// The demo being shown, if any.
    public private(set) var demo: Demo?

    /// Attract mode with the title screen just up: no demo yet.
    public init() {
        idleTicks = 0
        demo = nil
    }

    /// Advances attract mode one tick of the title screen with `input`.
    ///
    /// Any input stops a running demo and restarts the idle count. Otherwise a running demo ticks,
    /// and is dropped once finished, which restarts the idle count; with no demo, the tick counts
    /// as idle and the `Tuning.attractDelayTicks`th starts one.
    public mutating func tick(_ input: InputState) {
        if input != InputState() {
            reset()
        } else if demo != nil {
            demo?.tick()
            if demo?.isFinished == true {
                reset()
            }
        } else {
            idleTicks += 1
            if idleTicks >= Tuning.attractDelayTicks {
                demo = Demo()
            }
        }
    }

    /// Drops the demo and restarts the idle count: for when the title screen is left or the
    /// settings open.
    public mutating func reset() {
        idleTicks = 0
        demo = nil
    }
}
