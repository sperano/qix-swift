// Closing a stix: the flood fills that find the free areas holding the Qix, and the claim of every
// other free cell.

/// What closing a stix claimed.
public struct ClaimResult: Equatable, Sendable {
    /// The cells the stix claimed.
    public var cells: Int
    /// The board's claimed fraction after the claim, from 0 to 1.
    public var fraction: Float
    /// How the claimed cells were drawn: `Stix.claimKind()`.
    public var kind: DrawKind

    public init(cells: Int, fraction: Float, kind: DrawKind) {
        self.cells = cells
        self.fraction = fraction
        self.kind = kind
    }
}

/// What closing a stix did.
public struct CloseResult: Equatable, Sendable {
    /// What the stix claimed, or `nil` when it claimed nothing.
    public var claim: ClaimResult?
    /// For each Qix, in the order given, the free cells of the area holding it: the
    /// `Claim.regions` of their `Qix.cell`s. Two Qix share an area exactly when their sets are
    /// equal, so a close that leaves them apart shows here even when it claims nothing.
    public var regions: [BitSet]

    public init(claim: ClaimResult?, regions: [BitSet]) {
        self.claim = claim
        self.regions = regions
    }
}

/// The functions of qix-core's `claim` module.
public enum Claim {
    /// The free cells reachable from the cell `seed` by steps between 4-adjacent free cells that
    /// do not cross a segment of `stix`.
    ///
    /// Bit `y * width + x` of the result stands for cell `(x, y)`. The step between cells `(x, y)`
    /// and `(x + 1, y)` crosses the lattice edge from point `(x + 1, y)` to `(x + 1, y + 1)`; the
    /// step between `(x, y)` and `(x, y + 1)` the edge from `(x, y + 1)` to `(x + 1, y + 1)`. A
    /// seed off the board or on a claimed cell reaches nothing. Runs in `O(W * H)` with an
    /// explicit stack.
    public static func floodFree(_ board: Board, _ stix: Stix, _ seed: (UInt16, UInt16)) -> BitSet {
        flood(board, Walls(board, stix), seed)
    }

    /// The `floodFree` set of each of `seeds`, in order. A seed in the area of an earlier one gets
    /// a copy of its set instead of a new fill, so the whole runs in `O(W * H)` per distinct area
    /// plus a copy per seed.
    public static func regions(_ board: Board, _ stix: Stix, _ seeds: [(UInt16, UInt16)]) -> [BitSet] {
        let walls = Walls(board, stix)
        var sets: [BitSet] = []
        sets.reserveCapacity(seeds.count)
        for seed in seeds {
            let index = isFree(board, seed) ? cellIndex(board, seed) : nil
            let known = index.flatMap { index in sets.first { $0.contains(index) } }
            sets.append(known ?? flood(board, walls, seed))
        }
        return sets
    }

    /// Claims, as `kind`, every free cell that none of `kept` holds, and returns how many it
    /// claimed. With nothing kept, every free cell goes.
    @discardableResult
    public static func claim(_ board: inout Board, _ kept: [BitSet], _ kind: DrawKind) -> Int {
        let claimed = Cell.claimed(kind)
        var count = 0
        for y in 0 ..< board.height {
            for x in 0 ..< board.width {
                let index = cellIndex(board, (x, y))
                if isFree(board, (x, y)), !kept.contains(where: { $0.contains(index) }) {
                    board.setCell(x: x, y: y, to: claimed)
                    count += 1
                }
            }
        }
        return count
    }

    /// The free cells reachable from `seed` without crossing `walls`: see `floodFree`.
    private static func flood(_ board: Board, _ walls: Walls, _ seed: (UInt16, UInt16)) -> BitSet {
        var reached = BitSet(capacity: Int(board.width) * Int(board.height))
        guard isFree(board, seed) else { return reached }
        reached.insert(cellIndex(board, seed))
        var stack = [seed]
        while let cell = stack.popLast() {
            for next in walls.openNeighbours(cell) where isFree(board, next) && reached.insert(cellIndex(board, next)) {
                stack.append(next)
            }
        }
        return reached
    }

    /// Cell `(x, y)` is on the board and free.
    private static func isFree(_ board: Board, _ cell: (UInt16, UInt16)) -> Bool {
        board.cell(x: Int32(cell.0), y: Int32(cell.1)) == .free
    }

    /// The bit of cell `(x, y)` in a `floodFree` result; the cell must be on the board.
    private static func cellIndex(_ board: Board, _ cell: (UInt16, UInt16)) -> Int {
        Int(cell.1) * Int(board.width) + Int(cell.0)
    }
}

/// The unit lattice edges a stix covers, which a flood fill may not cross.
private struct Walls {
    let width: UInt16
    let height: UInt16
    /// Edge from point `(x, y)` to `(x, y + 1)` at bit `y * (width + 1) + x`.
    var vertical: BitSet
    /// Edge from point `(x, y)` to `(x + 1, y)` at bit `y * width + x`.
    var horizontal: BitSet

    /// The edges `stix` covers on `board`'s lattice.
    init(_ board: Board, _ stix: Stix) {
        (width, height) = (board.width, board.height)
        let (columns, rows) = (Int(width), Int(height))
        vertical = BitSet(capacity: (columns + 1) * rows)
        horizontal = BitSet(capacity: columns * (rows + 1))
        for (from, to) in stix.segments() {
            if from.x == to.x {
                for y in min(from.y, to.y) ..< max(from.y, to.y) {
                    addVertical(from.x, y)
                }
            } else {
                for x in min(from.x, to.x) ..< max(from.x, to.x) {
                    addHorizontal(x, from.y)
                }
            }
        }
    }

    /// Covers the edge from point `(x, y)` down to `(x, y + 1)`, unless it is off the lattice.
    mutating func addVertical(_ x: UInt16, _ y: UInt16) {
        if let index = verticalIndex(x, y) {
            vertical.insert(index)
        }
    }

    /// Covers the edge from point `(x, y)` right to `(x + 1, y)`, unless it is off the lattice.
    mutating func addHorizontal(_ x: UInt16, _ y: UInt16) {
        if let index = horizontalIndex(x, y) {
            horizontal.insert(index)
        }
    }

    /// The edge from point `(x, y)` down to `(x, y + 1)` is covered.
    func hasVertical(_ x: UInt16, _ y: UInt16) -> Bool {
        verticalIndex(x, y).map(vertical.contains) ?? false
    }

    /// The edge from point `(x, y)` right to `(x + 1, y)` is covered.
    func hasHorizontal(_ x: UInt16, _ y: UInt16) -> Bool {
        horizontalIndex(x, y).map(horizontal.contains) ?? false
    }

    /// The bit of the vertical edge below point `(x, y)`, if on the lattice.
    func verticalIndex(_ x: UInt16, _ y: UInt16) -> Int? {
        x <= width && y < height ? Int(y) * (Int(width) + 1) + Int(x) : nil
    }

    /// The bit of the horizontal edge right of point `(x, y)`, if on the lattice.
    func horizontalIndex(_ x: UInt16, _ y: UInt16) -> Int? {
        x < width && y <= height ? Int(y) * Int(width) + Int(x) : nil
    }

    /// The cells on the board 4-adjacent to `cell` whose shared edge with it no wall covers.
    func openNeighbours(_ cell: (UInt16, UInt16)) -> [(UInt16, UInt16)] {
        let (x, y) = cell
        var open: [(UInt16, UInt16)] = []
        if x > 0, !hasVertical(x, y) {
            open.append((x - 1, y))
        }
        if x + 1 < width, !hasVertical(x + 1, y) {
            open.append((x + 1, y))
        }
        if y > 0, !hasHorizontal(x, y) {
            open.append((x, y - 1))
        }
        if y + 1 < height, !hasHorizontal(x, y + 1) {
            open.append((x, y + 1))
        }
        return open
    }
}
