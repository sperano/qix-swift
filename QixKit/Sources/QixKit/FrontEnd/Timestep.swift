// Converts frame times into a whole number of fixed core ticks: qix-rs's `crates/qix/src/timestep.rs`.

/// Accumulates frame time and releases it as fixed ticks of `Tuning.tickHz`.
public struct FixedTimestep: Hashable, Sendable {
    /// Most ticks one frame may run. After a stall the rest of the backlog is dropped rather than
    /// caught up, so slow frames cannot snowball.
    public static let maxTicksPerFrame: UInt32 = 5

    /// Fraction of a tick by which a nearly complete tick still counts as complete, so a frame time
    /// just below the exact tick period in `Float`, such as `Float(1.0 / 60.0).nextDown`, still
    /// yields one tick per frame.
    static let tickSnap: Double = 1e-3

    /// Part of a tick owed but not run yet, in ticks.
    private var owed: Double = 0

    /// No time owed.
    public init() {}

    /// Adds a frame of `dt` seconds and returns how many ticks to run now.
    public mutating func advance(_ dt: Float) -> UInt32 {
        // `maximum`, like Rust's `f32::max` and unlike Swift's `max`, returns the other argument
        // when one is NaN: a NaN frame time runs no tick, and an infinite one, whose `owed - whole`
        // is NaN, owes nothing after it.
        let owed = owed + Double(Float.maximum(dt, 0)) * Double(Tuning.tickHz)
        let whole = (owed + Self.tickSnap).rounded(.down)
        self.owed = Double.maximum(owed - whole, 0)
        // `whole` is a non-negative integer, so the conversion only drops `.0`.
        return UInt32(min(whole, Double(Self.maxTicksPerFrame)))
    }
}
