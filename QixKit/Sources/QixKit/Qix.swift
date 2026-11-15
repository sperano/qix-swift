// The Qix: a line segment drifting at random through the free area, leaving a trail of its last
// positions.

/// The Qix, in playfield units.
///
/// It keeps its length: each tick its midpoint moves by `vel` and the segment turns about it by
/// `spin`. As long as it starts on free cells, every cell under its segment stays free.
public struct Qix: Equatable, Sendable {
    /// One endpoint of the segment.
    public private(set) var a: Vec2
    /// The other endpoint of the segment.
    public private(set) var b: Vec2
    /// The distance from `a` to `b`, kept exact: turning the segment tick after tick would
    /// otherwise let rounding stretch or shrink it.
    private let length: Float
    /// The displacement of the midpoint per tick.
    public private(set) var vel: Vec2
    /// The turn of the segment per tick, in radians.
    public private(set) var spin: Float
    /// The speeds the midpoint keeps within, in playfield units per tick.
    public private(set) var speed: ClosedRange<Float>
    /// The last segments, oldest first, the current one last; at most `Tuning.qixTrailLen` of
    /// them.
    public private(set) var trail: [(Vec2, Vec2)]

    /// A Qix on the segment from `a` to `b`, with `vel` and `spin`, kept within the first level's
    /// `Tuning.qixSpeed`; its trail holds that one segment.
    ///
    /// Nothing is checked: the caller puts it on free cells of the board it will tick on.
    public init(a: Vec2, b: Vec2, vel: Vec2, spin: Float) {
        self.init(a: a, b: b, vel: vel, spin: spin, speed: Tuning.qixSpeed)
    }

    /// `init(a:b:vel:spin:)`, kept within `speed`.
    private init(a: Vec2, b: Vec2, vel: Vec2, spin: Float, speed: ClosedRange<Float>) {
        self.a = a
        self.b = b
        length = (b - a).length
        self.vel = vel
        self.spin = spin
        self.speed = speed
        trail = [(a, b)]
        trail.reserveCapacity(Tuning.qixTrailLen)
    }

    /// A `Tuning.qixLength` Qix centred on `board`, at a random angle, heading a random way at a
    /// random speed within `Tuning.qixSpeed`, with a random spin.
    ///
    /// The cells it covers must be free.
    public static func spawn(_ board: Board, _ rng: inout Rng) -> Self {
        let centre = Vec2(x: Float(board.width), y: Float(board.height)) * 0.5
        return spawnAt(centre, Tuning.qixSpeed, &rng)
    }

    /// A `Tuning.qixLength` Qix centred on `centre`, at a random angle, heading a random way at a
    /// random speed within `speed`, which it keeps within from then on, with a random spin.
    ///
    /// The cells it covers must be free.
    public static func spawnAt(_ centre: Vec2, _ speed: ClosedRange<Float>, _ rng: inout Rng) -> Self {
        let half = Vec2.fromAngle(rng.rangeF32(0, tau)) * (Tuning.qixLength * 0.5)
        let initialSpeed = rng.rangeF32(speed.lowerBound, speed.upperBound)
        let vel = Vec2.fromAngle(rng.rangeF32(0, tau)) * initialSpeed
        let spin = rng.rangeF32(-Tuning.qixMaxSpin, Tuning.qixMaxSpin)
        return Self(a: centre - half, b: centre + half, vel: vel, spin: spin, speed: speed)
    }

    /// The segment a tick ago, or the current one when the Qix has not ticked yet.
    public var previous: (Vec2, Vec2) {
        trail.count >= 2 ? trail[trail.count - 2] : (a, b)
    }

    /// The cell under the midpoint: the seed of the area that stays free when a stix closes.
    public var cell: (UInt16, UInt16) {
        let mid = a.midpoint(b)
        return (saturatingUInt16(mid.x.rounded(.down)), saturatingUInt16(mid.y.rounded(.down)))
    }

    /// Advances the Qix by one tick on `board`: jitters its velocity and spin from `rng`, moves
    /// and turns it, bouncing off claimed cells and the board's edges, and records the new segment
    /// in the trail.
    public mutating func tick(_ board: Board, _ rng: inout Rng) {
        jitter(&rng)
        advance(board)
        if trail.count == Tuning.qixTrailLen {
            trail.removeFirst()
        }
        trail.append((a, b))
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.length == rhs.length && lhs.vel == rhs.vel
            && lhs.spin == rhs.spin && lhs.speed == rhs.speed
            && lhs.trail.elementsEqual(rhs.trail) { $0.0 == $1.0 && $0.1 == $1.1 }
    }

    /// Kicks the velocity and the spin by random amounts, keeping the speed within `speed` and the
    /// spin within `Tuning.qixMaxSpin`.
    private mutating func jitter(_ rng: inout Rng) {
        let kick = Vec2(
            x: rng.rangeF32(-Tuning.qixJitter, Tuning.qixJitter),
            y: rng.rangeF32(-Tuning.qixJitter, Tuning.qixJitter)
        )
        vel = clampSpeed(vel + kick, speed)
        let spin = spin + rng.rangeF32(-Tuning.qixSpinJitter, Tuning.qixSpinJitter)
        self.spin = clamp(spin, -Tuning.qixMaxSpin ... Tuning.qixMaxSpin)
    }

    /// Moves by the velocity and turns by the spin when the segment lands on free cells only.
    /// Otherwise it reflects: the first of the velocity mirrored on `x`, on `y`, on both, then the
    /// same with the spin reversed, that lands on free cells is taken and kept. When none does,
    /// the Qix stays put and reverses both for the next tick.
    private mutating func advance(_ board: Board) {
        let (x, y) = (vel.x, vel.y)
        let mirrors = [Vec2(x: x, y: y), Vec2(x: -x, y: y), Vec2(x: x, y: -y), Vec2(x: -x, y: -y)]
        for spin in [spin, -spin] {
            for vel in mirrors {
                let (a, b) = moved(vel, spin)
                if isFree(board, a, b) {
                    (self.vel, self.spin) = (vel, spin)
                    (self.a, self.b) = (a, b)
                    return
                }
            }
        }
        (vel, spin) = (-vel, -spin)
    }

    /// The segment moved by `vel` and turned by `spin` about its midpoint.
    private func moved(_ vel: Vec2, _ spin: Float) -> (Vec2, Vec2) {
        let mid = a.midpoint(b) + vel
        let half = (b - a).rotated(spin).withLength(length * 0.5)
        return (mid - half, mid + half)
    }
}

/// A full turn, in radians: Rust's `std::f32::consts::TAU`, which doubling `Float.pi` gives
/// exactly.
private let tau = 2 * Float.pi

/// `vel` scaled to the nearest speed within `bounds`; a standstill becomes the slowest speed along
/// `x`.
private func clampSpeed(_ vel: Vec2, _ bounds: ClosedRange<Float>) -> Vec2 {
    let speed = vel.length
    return speed > 0 ? vel * (clamp(speed, bounds) / speed) : Vec2(x: bounds.lowerBound, y: 0)
}

/// `value` clamped into `bounds`, as Rust's `f32::clamp`.
private func clamp(_ value: Float, _ bounds: ClosedRange<Float>) -> Float {
    min(max(value, bounds.lowerBound), bounds.upperBound)
}

/// Every cell the segment from `a` to `b` passes through is a free cell of `board`; cells off the
/// board read as claimed.
private func isFree(_ board: Board, _ a: Vec2, _ b: Vec2) -> Bool {
    Segment.cells(a, b).allSatisfy { !board.cell(x: $0.0, y: $0.1).isClaimed }
}

/// `value` as a `UInt16` the way Rust's `as` casts it: saturated at the type's bounds, NaN as
/// zero, where Swift's conversion would trap.
private func saturatingUInt16(_ value: Float) -> UInt16 {
    if value.isNaN || value <= 0 {
        return 0
    }
    if value >= Float(UInt16.max) {
        return .max
    }
    return UInt16(value)
}
