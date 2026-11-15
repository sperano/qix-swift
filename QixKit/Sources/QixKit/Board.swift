// The board: a grid of cells, each free or claimed.

/// How a claimed area was drawn, which decides its colour and its points.
public enum DrawKind: Hashable, Sendable {
    case fast
    case slow
}

/// One cell of the board.
public enum Cell: Hashable, Sendable {
    case free
    case claimed(DrawKind)

    /// The cell is claimed, however it was drawn.
    public var isClaimed: Bool {
        if case .claimed = self {
            return true
        }
        return false
    }
}

/// A `width x height` grid of cells, row by row from the top left.
public struct Board: Equatable, Sendable {
    /// What every cell outside the board reads as: claimed, so the board's edges are border like
    /// the edge of any claimed area. The draw kind has no meaning there; the outside is never
    /// painted or scored.
    public static let outside = Cell.claimed(.fast)

    /// The width in cells.
    public let width: UInt16
    /// The height in cells.
    public let height: UInt16
    private var cells: [Cell]

    /// A board of `width x height` free cells.
    ///
    /// - Precondition: neither dimension is zero.
    public init(width: UInt16, height: UInt16) {
        precondition(width > 0 && height > 0, "empty board \(width)x\(height)")
        self.width = width
        self.height = height
        cells = Array(repeating: .free, count: Int(width) * Int(height))
    }

    /// The cell at `(x, y)`, or `Board.outside` when that is off the board.
    public func cell(x: Int32, y: Int32) -> Cell {
        index(x: x, y: y).map { cells[$0] } ?? Self.outside
    }

    /// Sets the cell at `(x, y)`.
    ///
    /// - Precondition: `(x, y)` is on the board.
    public mutating func setCell(x: UInt16, y: UInt16, to cell: Cell) {
        guard let index = index(x: Int32(x), y: Int32(y)) else {
            preconditionFailure("cell (\(x), \(y)) is off the \(width)x\(height) board")
        }
        cells[index] = cell
    }

    /// The four cells touching the lattice point `point`, in reading order: top left, top right,
    /// bottom left, bottom right. Cells off the board read as `Board.outside`.
    public func cellsAround(_ point: Point) -> [Cell] {
        let (x, y) = (Int32(point.x), Int32(point.y))
        return [
            cell(x: x - 1, y: y - 1),
            cell(x: x, y: y - 1),
            cell(x: x - 1, y: y),
            cell(x: x, y: y),
        ]
    }

    /// The share of the board's cells that are claimed, from 0 to 1.
    public func claimedFraction() -> Float {
        let claimed = cells.lazy.filter(\.isClaimed).count
        return Float(claimed) / Float(cells.count)
    }

    /// The position of cell `(x, y)` in `cells`, if it is on the board.
    private func index(x: Int32, y: Int32) -> Int? {
        guard let x = UInt16(exactly: x), x < width, let y = UInt16(exactly: y), y < height else {
            return nil
        }
        return Int(y) * Int(width) + Int(x)
    }
}
