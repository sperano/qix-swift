// From frame samples to tick input: qix-rs's `InputLatch` (`crates/qix/src/input.rs`).

/// Turns per-frame samples into per-tick input: a press made in a frame that runs no tick waits for
/// the next tick, and a frame that runs several ticks delivers it to the first one only.
public struct InputLatch: Hashable, Sendable {
    private var pending = InputState()

    /// Nothing held or pressed.
    public init() {}

    /// Records a frame's sample: held controls replace the previous ones, presses add up until a
    /// tick takes them.
    public mutating func record(_ frame: InputState) {
        var next = frame
        next.confirm = pending.confirm || frame.confirm
        next.pause = pending.pause || frame.pause
        pending = next
    }

    /// The input for the next tick; clears the presses it delivers.
    public mutating func nextTick() -> InputState {
        let input = pending
        pending.confirm = false
        pending.pause = false
        return input
    }
}
