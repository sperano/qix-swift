// What the HUD above the playfield shows: the score, the high score, the level, the lives, the
// claimed share against the threshold, the Sparx meter and the multiplier. qix-rs's
// `crates/qix/src/render/hud.rs`, without its painting, which the app does.

import Foundation

/// What the HUD shows of one game, as text where it is text.
public struct Hud: Hashable, Sendable {
    /// Converts a fraction to a percentage.
    static let percent: Double = 100

    /// Tenths in one, to show percentages to a tenth.
    static let tenths: Double = 10

    /// Tenths of a percent added before rounding the claimed share down: absorbs the `Float`
    /// rounding of a share lying on a tenth, such as 70 % stored a hair below `0.7`, yet stays well
    /// under the share of one cell of a full board.
    static let tenthsRoundingSlack: Double = 1e-4

    public var score: String
    public var highScore: String
    public var level: String
    public var lives: UInt32
    /// The claimed share of the board, then the threshold.
    public var claimed: String
    public var meter: Meter
    /// The multiplier, none while it is the starting one.
    public var multiplier: String?

    public init(
        score: String, highScore: String, level: String, lives: UInt32, claimed: String, meter: Meter,
        multiplier: String?
    ) {
        self.score = score
        self.highScore = highScore
        self.level = level
        self.lives = lives
        self.claimed = claimed
        self.meter = meter
        self.multiplier = multiplier
    }

    /// The HUD of `game`, with the session's `highScore`.
    public init(game: Game, highScore: UInt32) {
        self.init(
            score: Numbers.thousands(game.score.points),
            highScore: Numbers.thousands(highScore),
            level: String(game.level),
            lives: game.lives,
            claimed: Self.claimed(game),
            meter: Meter(game.sparxMeter),
            multiplier: game.multiplier > Tuning.startingMultiplier ? "x\(game.multiplier)" : nil
        )
    }

    /// The claimed share of `game`'s board and its threshold, in percent: the share rounded down to
    /// a tenth, so it never shows a whole-percent threshold before the board reaches it, and the
    /// threshold rounded to the nearest whole percent.
    private static func claimed(_ game: Game) -> String {
        let fraction = Double(game.board.claimedFraction())
        let shown = (fraction * percent * tenths + tenthsRoundingSlack).rounded(.down) / tenths
        let threshold = Double(game.claimThreshold.fraction) * percent
        return String(format: "%.1f%% / %.0f%%", shown, threshold)
    }
}

/// The Sparx meter's bar.
public struct Meter: Hashable, Sendable {
    /// The share of the current countdown left, from 1 (full) to 0.
    public var fraction: Float
    /// What the countdown leads to, `nil` once the meter is spent.
    public var next: MeterExpiry?

    public init(fraction: Float, next: MeterExpiry?) {
        self.fraction = fraction
        self.next = next
    }

    /// The bar of `meter`.
    public init(_ meter: SparxMeter) {
        self.init(fraction: Float(meter.remaining) / Float(meter.length), next: meter.nextExpiry)
    }
}
