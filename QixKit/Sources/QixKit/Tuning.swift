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

    /// Ticks a direction is held while entering initials, or on a menu, before it repeats: a third
    /// of a second.
    public static let repeatDelayTicks: UInt32 = tickHz / 3

    /// Ticks between two repeats of a direction held while entering initials, or on a menu: ten a
    /// second.
    public static let repeatTicks: UInt32 = tickHz / 10
}
