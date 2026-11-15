// The player's marker: where it is on the lattice and whether it is drawing a stix.

/// What the marker is doing.
public enum MarkerState: Hashable, Sendable {
    /// On the border, moving along its edges.
    case onBorder
    /// Off the border, drawing a stix.
    case drawing
}

/// The player's marker.
public struct Marker: Hashable, Sendable {
    public var pos: Point
    public var state: MarkerState

    public init(pos: Point, state: MarkerState) {
        self.pos = pos
        self.state = state
    }

    /// A marker on the border at the centre of `board`'s bottom edge.
    public static func start(_ board: Board) -> Self {
        Self(pos: Point(x: board.width / 2, y: board.height), state: .onBorder)
    }

    /// Moves the marker one lattice step towards `dir` when that step follows a border edge of
    /// `board`; otherwise it stays put. Returns whether it moved.
    @discardableResult
    public mutating func stepAlongBorder(_ board: Board, _ dir: Dir) -> Bool {
        guard let next = borderStep(board, dir) else { return false }
        pos = next
        return true
    }

    /// The lattice point one step towards `dir` along a border edge of `board`, if that edge is
    /// border.
    public func borderStep(_ board: Board, _ dir: Dir) -> Point? {
        board.borderNeighbours(pos).first { $0.dir == dir }?.next
    }
}
