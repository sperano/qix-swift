// The rules every new game is set up with, as the settings choose them: the claim threshold and
// the lives it starts with.

/// The lives a game starts with, always in `Tuning.startingLivesRange`.
public struct StartingLives: Hashable, Sendable {
    /// The number of lives.
    public let get: UInt32

    /// `lives`, clamped into `Tuning.startingLivesRange`.
    public init(_ lives: UInt32) {
        let range = Tuning.startingLivesRange
        get = min(max(lives, range.lowerBound), range.upperBound)
    }

    /// `lives`, clamped into `Tuning.startingLivesRange`, a negative number or one past `UInt32`
    /// included: Rust's `From<i64>`.
    public init(clamping lives: Int64) {
        let range = Tuning.startingLivesRange
        self.init(UInt32(min(max(lives, Int64(range.lowerBound)), Int64(range.upperBound))))
    }

    /// `Tuning.startingLives`: Rust's `StartingLives::default()`.
    public init() {
        self.init(Tuning.startingLives)
    }
}

/// What `Game.restart` sets a new game up with; the default is the arcade's.
public struct Rules: Hashable, Sendable {
    /// The claimed fraction of the board that completes a level.
    public var threshold: ClaimThreshold
    /// The lives the game starts with.
    public var startingLives: StartingLives

    /// The rules given; the arcade's by default, as Rust's `Rules::default()`.
    public init(threshold: ClaimThreshold = ClaimThreshold(), startingLives: StartingLives = StartingLives()) {
        self.threshold = threshold
        self.startingLives = startingLives
    }
}
