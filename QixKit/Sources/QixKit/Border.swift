// The border graph: the lattice points and edges where free cells meet claimed ones. Sparx walk
// it and the marker follows it.

public extension Board {
    /// The lattice point `point` is on the border: its four surrounding cells, the outside
    /// counting as claimed, hold both free and claimed cells. A point off the board's lattice
    /// never is.
    func isBorder(_ point: Point) -> Bool {
        let cells = cellsAround(point)
        let claimed = cells.lazy.filter(\.isClaimed).count
        return claimed > 0 && claimed < cells.count
    }

    /// The lattice points one step from `point` along a border edge, with the direction of each
    /// step, in the order of `Dir.all`.
    func borderNeighbours(_ point: Point) -> [(dir: Dir, next: Point)] {
        let cells = cellsAround(point)
        return Dir.all.compactMap { dir in
            guard let next = dir.step(point), sidesDiffer(cells, dir) else { return nil }
            return (dir, next)
        }
    }

    /// The edge from `point` one step towards `dir` is border: the cells on its two sides, the
    /// outside counting as claimed, differ in claimed-ness. An edge leaving the board's lattice
    /// never is.
    func isBorderEdge(_ point: Point, _ dir: Dir) -> Bool {
        sidesDiffer(cellsAround(point), dir)
    }

    /// The edge from `point` one step towards `dir` runs through free space: the cells on both
    /// its sides are free. An edge leaving the board's lattice never does, since the outside
    /// counts as claimed.
    func isFreeEdge(_ point: Point, _ dir: Dir) -> Bool {
        let (side, otherSide) = edgeSides(cellsAround(point), dir)
        return side == .free && otherSide == .free
    }
}

/// The edge from a lattice point one step towards `dir` is border, given the point's
/// `Board.cellsAround`: the two cells on the edge's sides differ in claimed-ness.
private func sidesDiffer(_ cells: [Cell], _ dir: Dir) -> Bool {
    let (side, otherSide) = edgeSides(cells, dir)
    return side.isClaimed != otherSide.isClaimed
}

/// The two cells on the sides of the edge from a lattice point one step towards `dir`, given the
/// point's `Board.cellsAround`.
private func edgeSides(_ cells: [Cell], _ dir: Dir) -> (Cell, Cell) {
    let (topLeft, topRight, bottomLeft, bottomRight) = (cells[0], cells[1], cells[2], cells[3])
    switch dir {
    case .up: return (topLeft, topRight)
    case .down: return (bottomLeft, bottomRight)
    case .left: return (topLeft, bottomLeft)
    case .right: return (topRight, bottomRight)
    }
}
