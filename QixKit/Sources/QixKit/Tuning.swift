/// Gameplay tuning values, kept in one place so they can be adjusted by play.
///
/// Only the values the ported modules use so far; the rest arrive with the modules that need them.
public enum Tuning {
    /// Core ticks per second: every `Game.tick` advances the game by `1 / tickHz` seconds.
    public static let tickHz: UInt32 = 60

    /// Board width in cells; the playfield is one unit per cell.
    public static let boardW: UInt16 = 160

    /// Board height in cells; the playfield is one unit per cell.
    public static let boardH: UInt16 = 120

    /// Ticks between two lattice steps of the marker while a direction is held.
    public static let markerStepTicks: UInt32 = 2

    /// Ticks between two lattice steps of the marker drawing a slow stix: half the speed of a fast
    /// one, which steps every `markerStepTicks`.
    public static let slowStepTicks: UInt32 = 2 * markerStepTicks

    /// Length of the Qix's segment, in playfield units.
    public static let qixLength: Float = 16.0

    /// The speed of the Qix's midpoint at the first level, in playfield units per tick: random
    /// jitter changes it, within these bounds.
    public static let qixSpeed: ClosedRange<Float> = 0.3 ... 0.8

    /// The most the Qix's velocity changes by in one tick, on each axis, in playfield units per
    /// tick.
    public static let qixJitter: Float = 0.05

    /// The fastest the Qix turns, in radians per tick either way.
    public static let qixMaxSpin: Float = 0.05

    /// The most the Qix's spin changes by in one tick, in radians per tick.
    public static let qixSpinJitter: Float = 0.005

    /// Segments in the Qix's trail, its current one included: one per tick.
    public static let qixTrailLen = 32

    /// Half the side of the square around a drawing marker that the Qix kills it in, in playfield
    /// units.
    public static let markerHitHalfSize: Float = 0.5

    /// Ticks between two lattice steps of a Sparx along the border.
    public static let sparxStepTicks: UInt32 = 3

    /// Ticks between two lattice steps of a Super Sparx along the stix: as fast as the marker
    /// draws a fast stix, so it catches a marker that stands still or draws slow.
    public static let superSparxStepTicks: UInt32 = markerStepTicks

    /// Ticks the marker may stand still on the stix it draws before the fuse is lit at the stix's
    /// start: longer than a slow draw step, so drawing steadily never lights it.
    public static let fuseDelayTicks: UInt32 = tickHz / 2

    /// Ticks the lit fuse takes to burn one segment of the stix towards the marker.
    public static let fuseStepTicks: UInt32 = 12

    /// Lives at the start of a game (the arcade's default).
    public static let startingLives: UInt32 = 3

    /// Points between two extra lives: one each time the score crosses a multiple of it (a dip
    /// switch on the arcade).
    public static let extraLifeEvery: UInt32 = 30_000

    /// The most lives the player can have, the one being played included: an extra life past it
    /// is lost.
    public static let maxLives: UInt32 = 9

    /// The starting lives the settings may choose from; others are clamped into it.
    public static let startingLivesRange: ClosedRange<UInt32> = 1 ... maxLives

    /// Ticks after a death during which the Sparx cannot kill the marker and the marker cannot
    /// draw: two seconds.
    public static let respawnGraceTicks: UInt32 = 2 * tickHz

    /// Points a claimed cell scores at a level multiplier of one, drawn fast.
    public static let pointsPerCell: UInt32 = 10

    /// How many times the points of a fast claim a slow claim scores.
    public static let slowDrawFactor: UInt32 = 2

    /// The level multiplier a game starts with.
    public static let startingMultiplier: UInt32 = 1

    /// The highest level multiplier: splitting the Qix no longer raises it.
    public static let maxMultiplier: UInt32 = 9

    /// The claimed fraction of the board that completes a level, unless the settings change it.
    public static let claimThresholdDefault: Float = 0.75

    /// The claim thresholds the settings may choose from; others are clamped into it.
    public static let claimThresholdRange: ClosedRange<Float> = 0.50 ... 0.90

    /// Points of the level bonus for each whole percent point of the board claimed above the
    /// threshold.
    public static let bonusPerPercent: UInt32 = 1_000

    /// Ticks of each of the Sparx meter's two countdowns at the first level: thirty seconds.
    public static let sparxMeterTicks: UInt32 = 30 * tickHz

    /// The level a game starts at; levels count up from it.
    public static let firstLevel: UInt32 = 1

    /// Levels after the first over which the game gets harder: from level `firstLevel +
    /// difficultyRampLevels` on, every level is as hard as that one.
    public static let difficultyRampLevels: UInt32 = 10

    /// How much both bounds of `qixSpeed` rise with each level of the ramp, in playfield units per
    /// tick: the top speed reaches one unit per tick at the end of it.
    public static let qixSpeedPerLevel: Float = 0.02

    /// The first level with two Qix instead of one.
    public static let twoQixFromLevel: UInt32 = 3

    /// Sparx on the border at the start of the first level.
    public static let levelSparx = 2

    /// Levels of the ramp per extra Sparx at the start of a level.
    public static let levelsPerExtraSparx: UInt32 = 2

    /// How much shorter each level of the ramp makes the Sparx meter's countdowns: two seconds,
    /// down to ten at the end of it.
    public static let sparxMeterTicksPerLevel: UInt32 = 2 * tickHz

    /// Sparx the Sparx meter releases at the top centre when it first runs out.
    public static let extraSparx = 2

    /// Ticks a direction is held while entering initials, or on a menu, before it repeats: a third
    /// of a second.
    public static let repeatDelayTicks: UInt32 = tickHz / 3

    /// Ticks between two repeats of a direction held while entering initials, or on a menu: ten a
    /// second.
    public static let repeatTicks: UInt32 = tickHz / 10
}
