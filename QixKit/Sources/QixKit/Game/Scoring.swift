// Adding points to the score, and the extra lives they earn.

extension Game {
    /// Adds `points` to the score and grants the extra lives it earns (see `extraLives`), raising
    /// `Event.extraLife` for each.
    mutating func addScore(_ points: UInt32) {
        let before = score
        score.add(points)
        let earned = extraLives(before, score, lives)
        lives += earned
        events += Array(repeating: .extraLife, count: Int(earned))
    }
}
