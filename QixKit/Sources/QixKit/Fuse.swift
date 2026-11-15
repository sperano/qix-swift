// The fuse: lit when the marker stands still while drawing, it burns along the stix from its start
// towards the marker.

/// A lit fuse.
public struct Fuse: Hashable, Sendable {
    /// The index, in `Stix.points`, of the stix point the fuse has burnt to.
    public var pos: Int

    public init(pos: Int) {
        self.pos = pos
    }
}

/// What lights, burns and puts out the fuse of the stix being drawn.
struct FuseTimer: Hashable, Sendable {
    /// The fuse, `nil` while it is out.
    private(set) var fuse: Fuse?
    /// Ticks the marker has stood still while the fuse is out, or since the lit fuse last moved.
    private var ticks: UInt32 = 0

    /// A fuse that is out, its delay not started: Rust's `FuseTimer::default()`.
    init() {}

    /// Puts the fuse out and restarts the delay: the marker stepped, or it no longer draws a stix.
    mutating func putOut() {
        self = Self()
    }

    /// Advances one tick of a marker standing still at the stix point of index `head`: a fuse that
    /// is out is lit at the stix's start after `Tuning.fuseDelayTicks` such ticks, and a lit one
    /// moves one point towards `head` every `Tuning.fuseStepTicks`.
    mutating func stand(_ head: Int) {
        ticks += 1
        guard let lit = fuse else {
            if ticks >= Tuning.fuseDelayTicks {
                light()
            }
            return
        }
        if ticks >= Tuning.fuseStepTicks {
            ticks = 0
            fuse = Fuse(pos: min(lit.pos + 1, head))
        }
    }

    /// Lights the fuse at the stix's start at once, unless it is lit already: the marker is caught
    /// in a dead end.
    mutating func light() {
        if fuse == nil {
            fuse = Fuse(pos: 0)
            ticks = 0
        }
    }

    /// The lit fuse is at the stix point of index `head`, the marker's.
    func reached(_ head: Int) -> Bool {
        fuse?.pos == head
    }
}
