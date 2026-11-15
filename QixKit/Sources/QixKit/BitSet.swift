// A fixed-size set of indices, one bit per index.

/// A set of the indices `0..<capacity`, stored as one bit each.
public struct BitSet: Equatable, Sendable {
    /// Bits in one word of a `BitSet`.
    private static let wordBits = UInt64.bitWidth

    /// The number of indices the set can hold: it holds `0..<capacity`.
    public let capacity: Int
    private var words: [UInt64]

    /// An empty set that can hold the indices `0..<capacity`.
    ///
    /// - Precondition: `capacity` is not negative.
    public init(capacity: Int) {
        precondition(capacity >= 0, "negative capacity \(capacity)")
        self.capacity = capacity
        let (whole, rest) = capacity.quotientAndRemainder(dividingBy: Self.wordBits)
        words = Array(repeating: 0, count: rest > 0 ? whole + 1 : whole)
    }

    /// `index` is in the set. An index outside the capacity never is.
    public func contains(_ index: Int) -> Bool {
        index >= 0 && index < capacity && words[index / Self.wordBits] & Self.bit(index) != 0
    }

    /// Adds `index` to the set; `true` when it was not in it yet.
    ///
    /// - Precondition: `index` is in `0..<capacity`.
    @discardableResult
    public mutating func insert(_ index: Int) -> Bool {
        precondition(index >= 0, "index \(index) is negative")
        precondition(index < capacity, "index \(index) is past the capacity \(capacity)")
        let word = index / Self.wordBits
        let added = words[word] & Self.bit(index) == 0
        words[word] |= Self.bit(index)
        return added
    }

    /// The number of indices in the set.
    public func count() -> Int {
        words.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    /// The bit of `index` within its word.
    private static func bit(_ index: Int) -> UInt64 {
        1 << (index % wordBits)
    }
}
