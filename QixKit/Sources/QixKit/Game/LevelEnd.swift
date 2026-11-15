// Ending a level: a claim reaching the claim threshold, or a stix splitting the Qix apart, which
// raises the multiplier.

public extension Game {
    /// Sets the multiplier of the points every claim scores, clamped to
    /// `Tuning.startingMultiplier ... Tuning.maxMultiplier`.
    mutating func setMultiplier(_ multiplier: UInt32) {
        self.multiplier = min(max(multiplier, Tuning.startingMultiplier), Tuning.maxMultiplier)
    }
}

extension Game {
    /// Ends the level after the stix that `close` reports, its claim already scored. A stix
    /// leaving the Qix in different areas ends it at once with no bonus, even at the threshold,
    /// and raises the multiplier by one up to `Tuning.maxMultiplier`; else a claim taking the board
    /// to the threshold ends it and scores the level bonus. Either raises `Event.levelComplete`.
    mutating func endLevelAfter(_ close: CloseResult) {
        let fraction = board.claimedFraction()
        let split = splits(close.regions)
        let bonus: UInt32
        if split {
            multiplier = min(multiplier + 1, Tuning.maxMultiplier)
            bonus = 0
        } else if close.claim != nil, claimThreshold.isReached(fraction) {
            bonus = claimThreshold.bonus(fraction)
        } else {
            return
        }
        addScore(bonus)
        isLevelComplete = true
        events.append(.levelComplete(fraction: fraction, bonus: bonus, split: split))
    }
}

/// The Qix whose areas `regions` holds are not all in one: two Qix share an area exactly when
/// their sets are equal.
private func splits(_ regions: [BitSet]) -> Bool {
    zip(regions, regions.dropFirst()).contains { $0 != $1 }
}
