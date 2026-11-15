// Starting a game, and each of its levels, from the level table.

public extension Game {
    /// A game that has not ticked yet, at the start of `Tuning.firstLevel` on a free
    /// `Tuning.boardW x Tuning.boardH` board: see `startLevel`. Every random choice is drawn from
    /// `rng`.
    init(rng: Rng) {
        self.init(board: Board(width: Tuning.boardW, height: Tuning.boardH), qix: [], sparx: [], rng: rng)
        startLevel(Tuning.firstLevel)
    }

    /// Starts a new game on a free board of the same size, as `init(rng:)` does:
    /// `Tuning.firstLevel`, no score, the starting multiplier and no tick run, with the starting
    /// lives and the claim threshold of `rules`. Only the random sequence and the rules carry on.
    mutating func restart() {
        var game = Self(board: Board(width: board.width, height: board.height), qix: [], sparx: [], rng: rng)
        game.lives = rules.startingLives.get
        game.claimThreshold = rules.threshold
        game.rules = rules
        self = game
        startLevel(Tuning.firstLevel)
    }

    /// Sets the rules every later `restart` sets a game up with; the game being played keeps its
    /// lives and claim threshold.
    mutating func setRules(_ rules: Rules) {
        self.rules = rules
    }

    /// Starts level `level` (a level below `Tuning.firstLevel` starts the first) as
    /// `LevelConfig.forLevel` sets it up: a free board of the same size, the marker at the centre
    /// of its bottom edge, the Qix spread evenly along its middle row, the `Sparx.spawnLevel` on
    /// its top edge and a full Sparx meter.
    ///
    /// The score, the lives, the multiplier, the claim threshold, the rules, the tick count and
    /// the random sequence carry on; the stix, the fuse, a grace period, the completed level and
    /// the last tick's events are gone.
    mutating func startLevel(_ level: UInt32) {
        let level = max(level, Tuning.firstLevel)
        let config = LevelConfig.forLevel(level)
        let board = Board(width: board.width, height: board.height)
        let qix = spawnQix(board, config, &rng)
        let sparx = Sparx.spawnLevel(board, config.sparxCount)
        var game = Self(board: board, qix: qix, sparx: sparx, rng: rng)
        game.ticks = ticks
        game.level = level
        game.sparxMeter = SparxMeter(length: config.meterTicks)
        game.lives = lives
        game.score = score
        game.multiplier = multiplier
        game.claimThreshold = claimThreshold
        game.rules = rules
        self = game
    }
}

/// The `config.qixCount` Qix of a level on `board`, drawn from `rng`: spread evenly along the
/// board's middle row, the ends excluded, so a single one is at its centre, each kept within
/// `config.qixSpeed`.
private func spawnQix(_ board: Board, _ config: LevelConfig, _ rng: inout Rng) -> [Qix] {
    let (width, height) = (Float(board.width), Float(board.height))
    let slots = Float(config.qixCount + 1)
    return (0 ..< config.qixCount).map { index in
        let centre = Vec2(x: width * Float(index + 1) / slots, y: height * 0.5)
        return Qix.spawnAt(centre, config.qixSpeed, &rng)
    }
}
