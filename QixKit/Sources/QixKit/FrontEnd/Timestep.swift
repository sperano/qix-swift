// Converts frame times into a whole number of fixed core ticks: qix-rs's `crates/qix/src/timestep.rs`.

/// Accumulates frame time and releases it as fixed ticks of `Tuning.tickHz`.
public struct FixedTimestep: Hashable, Sendable {
    /// Most ticks one frame may run. After a stall the rest of the backlog is dropped rather than
    /// caught up, so slow frames cannot snowball.
    public static let maxTicksPerFrame: UInt32 = 5

    /// Fraction of a tick by which a nearly complete tick still counts as complete, so a frame time
    /// such as `1.0 / 60.0` that rounds below the exact tick period in `Float` still yields one tick
    /// per frame.
    static let tickSnap: Double = 1e-3

    /// Part of a tick owed but not run yet, in ticks.
    private var owed: Double = 0

    /// No time owed.
    public init() {}

    /// Adds a frame of `dt` seconds and returns how many ticks to run now.
    public mutating func advance(_ dt: Float) -> UInt32 {
        // `max` also turns a NaN frame time into zero, as Rust's `f32::max` does.
        let frame = dt.isNaN ? 0 : max(dt, 0)
        let owed = owed + Double(frame) * Double(Tuning.tickHz)
        let whole = (owed + Self.tickSnap).rounded(.down)
        self.owed = max(owed - whole, 0)
        // `whole` is a non-negative integer, so the conversion only drops `.0`.
        return UInt32(min(whole, Double(Self.maxTicksPerFrame)))
    }
}
