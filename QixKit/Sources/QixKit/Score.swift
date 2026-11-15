// Points: what a claim scores and the player's running total.

/// The points `result` scores at `levelMultiplier`: `Tuning.pointsPerCell` per claimed cell times
/// the multiplier, times `Tuning.slowDrawFactor` for a `DrawKind.slow` claim. Saturates at
/// `UInt32.max`.
public func scoreForClaim(_ result: ClaimResult, _ levelMultiplier: UInt32) -> UInt32 {
    let factor: UInt32 = switch result.kind {
    case .fast: 1
    case .slow: Tuning.slowDrawFactor
    }
    let cells = UInt32(exactly: result.cells) ?? .max
    return [Tuning.pointsPerCell, levelMultiplier, factor].reduce(cells, saturatingMultiply)
}

/// The extra lives a player with `lives` earns when the score goes from `before` to `after`: one
/// for every multiple of `Tuning.extraLifeEvery` crossed, as many as fit below `Tuning.maxLives`.
public func extraLives(_ before: Score, _ after: Score, _ lives: UInt32) -> UInt32 {
    let steps = saturatingSubtract(after.points / Tuning.extraLifeEvery, before.points / Tuning.extraLifeEvery)
    return min(steps, saturatingSubtract(Tuning.maxLives, lives))
}

/// The player's points, zero at the start of a game.
public struct Score: Hashable, Sendable {
    /// The points scored so far.
    public private(set) var points: UInt32 = 0

    /// No points: Rust's `Score::default()`.
    public init() {}

    /// Adds `points`, saturating at `UInt32.max`.
    public mutating func add(_ points: UInt32) {
        let (sum, overflow) = self.points.addingReportingOverflow(points)
        self.points = overflow ? .max : sum
    }
}

/// `lhs * rhs`, saturating at `UInt32.max`, as Rust's `saturating_mul`.
func saturatingMultiply(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
    let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    return overflow ? .max : product
}

/// `lhs - rhs`, saturating at zero, as Rust's `saturating_sub`.
func saturatingSubtract(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
    lhs > rhs ? lhs - rhs : 0
}
