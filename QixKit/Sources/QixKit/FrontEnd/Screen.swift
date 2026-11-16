// The screens over the playfield outside play: the title with the high scores and the controls,
// the banner of its demo, the pause, the end of a level, the end of the game and the entry of a high score. qix-rs's
// `crates/qix/src/render/screen.rs` and `high_score.rs`, without their painting, which the app
// does, and with the keys, the taps and the initials field of the iPhone.

import Foundation

/// The text of a screen, all centred: a heading, the rows of a table in a monospace font, then
/// lines.
public struct Screen: Hashable, Sendable {
    /// Converts a fraction to a percentage.
    static let percent: Float = 100

    /// What the confirm press is named on screen: a tap anywhere but on a touch control, or the key.
    static let confirmName = "Tap or press Return"

    /// What the pause press is named on screen: the key, or the HUD's button.
    static let pauseName = "Escape or the pause button"

    public var heading: String
    public var table: [String]
    public var lines: [String]

    public init(heading: String, table: [String] = [], lines: [String]) {
        self.heading = heading
        self.table = table
        self.lines = lines
    }

    /// The screen `session` shows over the playfield, none while playing.
    public init?(session: Session) {
        let game = session.game
        switch session.state {
        case .title:
            self = .title(session.highScores)
        case .playing:
            return nil
        case .paused:
            self = .paused
        case let .levelComplete(fraction, bonus, split):
            self = .levelComplete(game, fraction: fraction, bonus: bonus, split: split)
        case .gameOver:
            self = .gameOver(game, session.highScores)
        case .highScoreEntry:
            self = .highScoreEntry(game, session.highScores)
        }
    }

    /// The title screen, with `highScores` and the controls.
    public static func title(_ highScores: HighScores) -> Self {
        Self(
            heading: "QIX",
            table: HighScoreTable.rows(highScores),
            lines: [
                "Arrows: move",
                "hold Z while moving: draw fast",
                "hold X while moving: draw slow, x\(Tuning.slowDrawFactor) points",
                "\(pauseName): pause",
                "",
                "\(confirmName) to start",
            ]
        )
    }

    /// The banner over the attract-mode demo: the demo plays on under it, and a tap starts a game.
    public static let demo = Self(heading: "DEMO", lines: ["\(confirmName) to play"])

    /// The pause overlay.
    public static let paused = Self(heading: "PAUSED", lines: ["Press \(pauseName) to resume"])

    /// The end of `game`'s level, which claimed `fraction` of the board and scored `bonus`, or
    /// ended by a `split`.
    public static func levelComplete(_ game: Game, fraction: Float, bonus: UInt32, split: Bool) -> Self {
        var lines = split ? ["The Qix are split apart!"] : []
        lines += [
            String(format: "Claimed %.1f%%", fraction * percent),
            "Bonus \(Numbers.thousands(bonus))",
            "Multiplier x\(game.multiplier)",
            "",
            "\(confirmName) for level \(game.level + 1)",
        ]
        return Self(heading: "LEVEL \(game.level) COMPLETE", lines: lines)
    }

    /// The end of `game`, with its final score and whether it makes `highScores`.
    public static func gameOver(_ game: Game, _ highScores: HighScores) -> Self {
        let points = game.score.points
        var lines = ["Final score \(Numbers.thousands(points))"]
        if highScores.qualifies(points) {
            lines.append("A new high score!")
        }
        lines += ["", "\(confirmName) to continue"]
        return Self(heading: "GAME OVER", lines: lines)
    }

    /// What the initials field asks for the initials of `game`'s score, which makes `highScores`:
    /// the score and its rank. The field itself is the app's (`InitialsField`).
    public static func highScoreEntry(_ game: Game, _ highScores: HighScores) -> Self {
        let points = game.score.points
        var score = "Score \(Numbers.thousands(points))"
        if let rank = highScores.rank(points) {
            score += ", rank \(rank + 1)"
        }
        return Self(heading: "NEW HIGH SCORE", lines: [score, "Type your initials, then Done"])
    }
}

/// The high score table as the title screen lists it.
public enum HighScoreTable {
    /// The rows of `highScores`, best first: rank, initials and score, with the ranks and scores
    /// right-aligned for a monospace font.
    public static func rows(_ highScores: HighScores) -> [String] {
        let entries = highScores.entries
        let scores = entries.map { Numbers.thousands($0.score) }
        let scoreWidth = scores.map(\.count).max() ?? 0
        let rankWidth = String(entries.count).count
        return zip(entries, scores).enumerated().map { i, pair in
            let (entry, score) = pair
            return "\(padded(String(i + 1), rankWidth)). \(entry.name)  \(padded(score, scoreWidth))"
        }
    }

    /// `text` right-aligned in `width` characters with spaces.
    private static func padded(_ text: String, _ width: Int) -> String {
        String(repeating: " ", count: max(width - text.count, 0)) + text
    }
}
