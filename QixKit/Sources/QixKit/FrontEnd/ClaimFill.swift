// The fill animation of a claim: the cells a claim takes flash, then fade into the colour of their
// fill. qix-rs's `crates/qix/src/claim_fill.rs`.
//
// The core only keeps the board as it is now, so the animation finds the cells a claim took by
// comparing the board with the one it saw last.

/// The cells the last claim took, while their animation runs.
public struct ClaimFill: Sendable {
    /// Ticks a claim's fill animation lasts: under half a second.
    public static let claimFillTicks: UInt32 = 24

    /// The board as the last tick saw it.
    private var seen: Board
    /// The cells the last claim took, as runs along their rows.
    private var freshRuns: [CellRun] = []
    /// Ticks of the animation still to run, zero when none runs.
    private var ticksLeft: UInt32 = 0

    /// No animation, on a board seen as `board`.
    public init(board: Board) {
        seen = board
    }

    /// Runs one tick of the animation with `board` shown: cells claimed since the last tick start a
    /// new one, which replaces the one running. A board that lost claimed cells (a new level, a new
    /// game, another game shown) is not a claim: the animation stops.
    public mutating func tick(_ board: Board) {
        ticksLeft = ticksLeft > 0 ? ticksLeft - 1 : 0
        guard board != seen else { return }
        if let gained = Self.claimedSince(seen, board) {
            freshRuns = BoardShapes.claimedRuns(gained)
            ticksLeft = Self.claimFillTicks
        } else {
            freshRuns = []
            ticksLeft = 0
        }
        seen = board
    }

    /// The cells of the claim being animated, and how far the animation is, from 0 on the tick of
    /// the claim towards 1; nil when no animation runs.
    public var fresh: (runs: [CellRun], progress: Float)? {
        guard ticksLeft > 0 else { return nil }
        let done = Self.claimFillTicks - ticksLeft
        return (freshRuns, Float(done) / Float(Self.claimFillTicks))
    }

    /// A board holding only the cells claimed on `now` that were free on `before`, or nil when the
    /// two differ in size or `now` has lost a claimed cell.
    private static func claimedSince(_ before: Board, _ now: Board) -> Board? {
        let (width, height) = (now.width, now.height)
        guard before.width == width, before.height == height else { return nil }
        var gained = Board(width: width, height: height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let (was, cell) = (before.cell(x: Int32(x), y: Int32(y)), now.cell(x: Int32(x), y: Int32(y)))
                switch (was, cell) {
                case (.free, .claimed): gained.setCell(x: x, y: y, to: cell)
                case (.claimed, .free): return nil
                default: break
                }
            }
        }
        return gained
    }
}
