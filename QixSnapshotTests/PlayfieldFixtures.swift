import QixKit

/// The sessions the snapshot tests draw, played from fixed seeds by fixed scripts, so every run
/// draws the same frames. QixKit only: the script's outcome can be checked with `swift test`.
enum PlayfieldFixtures {
    /// Seed of every game the fixtures play.
    static let seed: UInt64 = 0

    /// One leg of a script: `steps` lattice steps towards `dir`, drawing `kind`, or along the
    /// border without drawing; with no direction, `steps` ticks standing still.
    struct Leg {
        let dir: Dir?
        let kind: DrawKind?
        let steps: UInt32

        /// Ticks the leg holds its input.
        var ticks: UInt32 {
            guard dir != nil else { return steps }
            return steps * (kind == .slow ? Tuning.slowStepTicks : Tuning.markerStepTicks)
        }

        var input: InputState {
            InputState(dir: dir, fast: kind == .fast, slow: kind == .slow)
        }
    }

    /// From the marker's start: along the border to the left, a fast stix up, right and back down
    /// that claims a block, along the border to the right, then a stix drawn slow up and fast right that
    /// stops long enough for its fuse to light and burn one point.
    static let script = [
        Leg(dir: .left, kind: nil, steps: 24),
        Leg(dir: .up, kind: .fast, steps: 36),
        Leg(dir: .right, kind: .fast, steps: 18),
        Leg(dir: .down, kind: .fast, steps: 36),
        Leg(dir: .right, kind: nil, steps: 40),
        Leg(dir: .up, kind: .slow, steps: 16),
        Leg(dir: .right, kind: .fast, steps: 8),
        Leg(dir: nil, kind: nil, steps: Tuning.fuseDelayTicks + Tuning.fuseStepTicks),
    ]

    /// A few entries for the title screen's table.
    static let highScores: HighScores = {
        let entries = [("QIX", UInt32(123_450)), ("ABC", 48_210), ("ZED", 9_870)]
        return HighScores(entries.compactMap { name, score in
            (try? Initials(name)).map { HighScore(name: $0, score: score) }
        })
    }()

    /// A new session on the title screen, with `highScores`.
    static func title() -> Session {
        Session(game: Game(rng: Rng(seed: seed)), highScores: highScores)
    }

    /// A session started from the title and played through `script`.
    static func inPlay() -> Session {
        var session = title()
        session.tick(InputState(confirm: true))
        for leg in script {
            for _ in 0 ..< leg.ticks {
                session.tick(leg.input)
            }
        }
        return session
    }

    /// Ticks of the demo the attract snapshot shows: a slow stix drawn up and left after the
    /// first claim.
    static let demoTicks: UInt32 = 660

    /// Ticks into its animation the claim of the flash snapshot is shown at: a third of the way.
    static let flashTicks: UInt32 = ClaimFill.claimFillTicks / 3

    /// A loop over `title()` sitting idle until its demo starts, then `demoTicks` ticks into it.
    static func demo() -> GameLoop {
        var loop = GameLoop(session: title())
        for _ in 0 ..< Tuning.attractDelayTicks + demoTicks {
            loop.advance(1 / Float(Tuning.tickHz))
        }
        return loop
    }

    /// The session of `inPlay` stopped `flashTicks` ticks after the script's claim, with the claim's
    /// animation as the loop runs it; past the script when there is no claim.
    static func claimFlash() -> (session: Session, fill: ClaimFill) {
        var session = title()
        session.tick(InputState(confirm: true))
        var fill = ClaimFill(board: session.game.board)
        let flash = Float(flashTicks) / Float(ClaimFill.claimFillTicks)
        for leg in script {
            for _ in 0 ..< leg.ticks {
                session.tick(leg.input)
                fill.tick(session.game.board)
                if fill.fresh?.progress == flash {
                    return (session, fill)
                }
            }
        }
        return (session, fill)
    }

    /// `inPlay`, paused.
    static func paused() -> Session {
        var session = inPlay()
        session.tick(InputState(pause: true))
        return session
    }
}

extension PlayfieldFixtures {
    /// A full table, the tallest the title screen gets, with the widest scores.
    static let fullHighScores: HighScores = {
        let names = ["QIX", "ABC", "ZED", "MAX", "SPX", "FUS", "STX", "LVL", "TOP", "END"]
        let scores = (0 ..< UInt32(Tuning.highScoreCount)).map { 9_876_543 - $0 * 876_543 }
        return HighScores(zip(names, scores).compactMap { name, score in
            (try? Initials(name)).map { HighScore(name: $0, score: score) }
        })
    }()

    /// A HUD whose every value is as wide as a game makes it.
    static let widestHud = Hud(
        score: "99,999,999", highScore: "99,999,999", level: "99", lives: 14, claimed: "100.0% / 90%",
        meter: Meter(fraction: 0.5, next: .super), multiplier: "x9"
    )
}
