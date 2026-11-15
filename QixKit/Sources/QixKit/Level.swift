// Levels: how hard each one is, and completing one at the claim threshold with the bonus above it.

/// Percent points in a whole board.
private let percent: Double = 100

/// Percent points added before rounding down the share above the threshold: absorbs the `Float`
/// rounding of a fraction lying on a whole percent, such as 76 % stored a hair below `0.76`, yet
/// stays well under the share of one cell of a full board.
private let percentRoundingSlack: Double = 1e-4

/// Qix of a level before `Tuning.twoQixFromLevel`, and from it on.
private let oneQix = 1
private let twoQix = 2

/// How hard a level is: what `Game.startLevel` sets it up with.
public struct LevelConfig: Hashable, Sendable {
    /// The speeds each Qix keeps its midpoint within, in playfield units per tick.
    public var qixSpeed: ClosedRange<Float>
    /// The Qix on the board.
    public var qixCount: Int
    /// The Sparx on the border at the start of the level.
    public var sparxCount: Int
    /// Ticks of each of the Sparx meter's two countdowns.
    public var meterTicks: UInt32

    public init(qixSpeed: ClosedRange<Float>, qixCount: Int, sparxCount: Int, meterTicks: UInt32) {
        self.qixSpeed = qixSpeed
        self.qixCount = qixCount
        self.sparxCount = sparxCount
        self.meterTicks = meterTicks
    }

    /// The configuration of level `level`, counted from `Tuning.firstLevel` (a lower one plays as
    /// the first). Each level of the `Tuning.difficultyRampLevels` after the first raises the
    /// Qix's speed by `Tuning.qixSpeedPerLevel` and shortens the meter by
    /// `Tuning.sparxMeterTicksPerLevel`, and every `Tuning.levelsPerExtraSparx` of them add a
    /// Sparx; later levels are as hard as the last of the ramp. There are two Qix from
    /// `Tuning.twoQixFromLevel` on.
    ///
    /// The meter's countdowns stay positive at the end of the ramp: `Tuning.sparxMeterTicks` is
    /// longer than the ramp takes off (a compile-time check in qix-rs, a test here).
    public static func forLevel(_ level: UInt32) -> Self {
        let ramp = min(saturatingSubtract(level, Tuning.firstLevel), Tuning.difficultyRampLevels)
        let speedup = Float(ramp) * Tuning.qixSpeedPerLevel
        let extraSparx = Int(ramp / Tuning.levelsPerExtraSparx)
        return Self(
            qixSpeed: Tuning.qixSpeed.lowerBound + speedup ... Tuning.qixSpeed.upperBound + speedup,
            qixCount: level >= Tuning.twoQixFromLevel ? twoQix : oneQix,
            sparxCount: Tuning.levelSparx + extraSparx,
            meterTicks: Tuning.sparxMeterTicks - ramp * Tuning.sparxMeterTicksPerLevel
        )
    }
}

/// The claimed fraction of the board that completes a level, always in
/// `Tuning.claimThresholdRange`.
public struct ClaimThreshold: Hashable, Sendable {
    /// The threshold, as a fraction of the board from 0 to 1.
    public let fraction: Float

    /// The threshold `fraction`, clamped into `Tuning.claimThresholdRange`; a NaN gives
    /// `Tuning.claimThresholdDefault`.
    public init(_ fraction: Float) {
        let range = Tuning.claimThresholdRange
        self.fraction = fraction.isNaN ? Tuning.claimThresholdDefault
            : min(max(fraction, range.lowerBound), range.upperBound)
    }

    /// `Tuning.claimThresholdDefault`: Rust's `ClaimThreshold::default()`.
    public init() {
        self.init(Tuning.claimThresholdDefault)
    }

    /// Whether a board claimed to `fraction` completes the level: it is at the threshold or above.
    public func isReached(_ fraction: Float) -> Bool {
        fraction >= self.fraction
    }

    /// The bonus of a level completed with `fraction` of the board claimed:
    /// `Tuning.bonusPerPercent` for each whole percent point above the threshold, zero below it.
    /// Saturates at `UInt32.max`.
    public func bonus(_ fraction: Float) -> UInt32 {
        let above = (Double(fraction) - Double(self.fraction)) * percent
        let percent = saturatingUInt32((above + percentRoundingSlack).rounded(.down))
        return saturatingMultiply(percent, Tuning.bonusPerPercent)
    }
}

/// `value` as a `UInt32` the way Rust's `as` casts it: saturated at the type's bounds, so a
/// negative share is zero, and NaN as zero, where Swift's conversion would trap.
private func saturatingUInt32(_ value: Double) -> UInt32 {
    if value.isNaN || value <= 0 {
        return 0
    }
    return value >= Double(UInt32.max) ? .max : UInt32(value)
}
