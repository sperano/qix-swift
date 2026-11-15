// The high score table: the best `Tuning.highScoreCount` scores, each with the initials of who
// made it.

/// One line of the table: a score and who made it.
public struct HighScore: Hashable, Sendable, Codable {
    public var name: Initials
    public var score: UInt32

    /// `score`, made by `name`.
    public init(name: Initials, score: UInt32) {
        self.name = name
        self.score = score
    }
}

/// The best scores, best first, at most `Tuning.highScoreCount` of them; a score equal to one
/// already in the table ranks below it.
///
/// It encodes as the list of its entries. Decoding skips each entry that is not a valid
/// `HighScore` (bad initials, a score out of range, a missing field), then goes through
/// `init(_:)`, so a stored list edited by hand still makes a valid table; only a value that is
/// not a list at all fails.
public struct HighScores: Hashable, Sendable {
    /// The entries, best first.
    public private(set) var entries: [HighScore]

    /// An empty table: Rust's `HighScores::default()`.
    public init() {
        entries = []
    }

    /// The table of `entries` in any order: sorted best first (equal scores keep their order),
    /// scores of zero dropped, and cut to `Tuning.highScoreCount`. Rust's `From<Vec<HighScore>>`.
    public init(_ entries: [HighScore]) {
        // `sort(by:)` is stable, as Rust's `sort_by_key` is.
        let sorted = entries.filter { $0.score > 0 }.sorted { $0.score > $1.score }
        self.entries = Array(sorted.prefix(Tuning.highScoreCount))
    }

    /// The best score of the table, zero when it is empty.
    public var best: UInt32 {
        entries.first?.score ?? 0
    }

    /// The index `score` would take in the table, or nil when it does not make it: a score of zero
    /// never does, nor one no better than the last of a full table.
    public func rank(_ score: UInt32) -> Int? {
        let rank = entries.firstIndex { $0.score < score } ?? entries.count
        return score > 0 && rank < Tuning.highScoreCount ? rank : nil
    }

    /// Whether `score` makes it into the table.
    public func qualifies(_ score: UInt32) -> Bool {
        rank(score) != nil
    }

    /// Puts `entry` at its rank, dropping the last entry of a full table, and returns the rank;
    /// leaves the table alone and returns nil when the score does not qualify.
    @discardableResult
    public mutating func insert(_ entry: HighScore) -> Int? {
        guard let rank = rank(entry.score) else { return nil }
        entries.insert(entry, at: rank)
        entries.removeSubrange(min(entries.count, Tuning.highScoreCount)...)
        return rank
    }
}

extension HighScores: Codable {
    /// The table of the valid entries of a stored list, as `init(_:)` makes it; an element that is
    /// not a valid `HighScore` is skipped.
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var entries: [HighScore] = []
        while !container.isAtEnd {
            if let entry = try? container.decode(HighScore.self) {
                entries.append(entry)
            } else if try !container.decodeNil() {
                _ = try container.decode(SkippedEntry.self)
            }
        }
        self.init(entries)
    }

    /// Stores the table as the list of its entries, best first.
    public func encode(to encoder: any Encoder) throws {
        try entries.encode(to: encoder)
    }
}

/// An element of a stored table that is not a valid `HighScore`: decoding it reads nothing, which
/// moves the list past it. Rust's `IgnoredAny`.
private struct SkippedEntry: Decodable {
    init(from _: any Decoder) {}
}
