// The Sparx: enemies walking the border graph, and Super ones the stix, that kill the marker on
// contact.

/// What a Sparx is allowed to walk on.
public enum SparxKind: Hashable, Sendable {
    /// Walks the border only.
    case normal
    /// Also chases the marker along the stix: from the stix's start it walks the stix towards the
    /// marker.
    case `super`
}

/// A Sparx on a lattice point of the border, or of the stix while a `SparxKind.super` one chases
/// along it, heading `dir`.
public struct Sparx: Hashable, Sendable {
    /// The headings of the two Sparx of a pair, first to last.
    static let pair: [Dir] = [.left, .right]

    public var pos: Point
    public var dir: Dir
    public var kind: SparxKind

    public init(pos: Point, dir: Dir, kind: SparxKind) {
        self.pos = pos
        self.dir = dir
        self.kind = kind
    }

    /// The two `SparxKind.normal` Sparx of a level start: on the border point nearest the centre
    /// of `board`'s top edge, one heading left and the other right.
    public static func spawnPair(_ board: Board) -> [Self] {
        let pos = topCentre(board)
        return pair.map { Self(pos: pos, dir: $0, kind: .normal) }
    }

    /// `count` `SparxKind.normal` Sparx on the border point nearest the centre of `board`'s top
    /// edge, like `spawnPair`: heading left and right in turn, the first left.
    public static func spawnAtTop(_ board: Board, _ count: Int) -> [Self] {
        let pos = topCentre(board)
        return (0 ..< count).map { Self(pos: pos, dir: pair[$0 % pair.count], kind: .normal) }
    }

    /// The `count` `SparxKind.normal` Sparx of a level start, in pairs spread evenly along
    /// `board`'s top edge (each on the border point nearest its spot), the first of each pair
    /// heading left and the second right; an odd count leaves the last pair one short. Two Sparx
    /// are the `spawnPair`.
    public static func spawnLevel(_ board: Board, _ count: Int) -> [Self] {
        let pairs = (count + pair.count - 1) / pair.count
        return (0 ..< count).map { index in
            let pos = topPoint(board, spread(board.width, index / pair.count, pairs))
            return Self(pos: pos, dir: pair[index % pair.count], kind: .normal)
        }
    }

    /// Moves one step along a border edge of `board`: straight on when it can, else a random
    /// sideways edge, back only at a dead end; a Sparx with no border edge stays put.
    public mutating func step(_ board: Board, _ rng: inout Rng) {
        let edges = board.borderNeighbours(pos).map(\.dir)
        guard let dir = Self.turn(dir, edges, &rng), let next = dir.step(pos) else { return }
        pos = next
        self.dir = dir
    }

    /// The Sparx walks `stix` instead of the border: it is `SparxKind.super` and on a point of the
    /// stix, its start included.
    public func chasesAlong(_ stix: Stix) -> Bool {
        kind == .super && stix.containsPoint(pos)
    }

    /// Moves one lattice step along `stix` towards its head, where the marker is; a Sparx at the
    /// head or off the stix stays put.
    public mutating func stepAlongStix(_ stix: Stix) {
        guard let dir = stix.towardsHead(pos), let next = dir.step(pos) else { return }
        pos = next
        self.dir = dir
    }

    /// Moves to the border point of `board` nearest the Sparx's point (the fewest lattice steps
    /// away, the first in reading order among equally near ones) when that point is no longer on
    /// the border; its heading is kept.
    public mutating func snapToBorder(_ board: Board) {
        if board.isBorder(pos) {
            return
        }
        if let nearest = nearestBorderPoint(board, pos) {
            pos = nearest
        }
    }

    /// The Sparx, having moved from `from` to its point this tick, touched the marker, which moved
    /// from `markerFrom` to `markerTo`: they end on the same point, or they swapped points.
    public func hitsMarker(_ from: Point, _ markerFrom: Point, _ markerTo: Point) -> Bool {
        pos == markerTo || (pos == markerFrom && from == markerTo)
    }

    /// The direction a Sparx heading `dir` leaves a point by, given the directions of the point's
    /// border edges as `edges`: straight on when it can; else one of the edges other than back,
    /// drawn from `rng` when there are several; back only at a dead end. `nil` when the point has
    /// no edge at all.
    ///
    /// `rng` is drawn from only when there is a choice to make.
    static func turn(_ dir: Dir, _ edges: [Dir], _ rng: inout Rng) -> Dir? {
        if edges.contains(dir) {
            return dir
        }
        let back = dir.opposite
        let sideways = edges.filter { $0 != back }
        switch sideways.count {
        case 0: return edges.first
        case 1: return sideways[0]
        default: return sideways[rng.below(sideways.count)]
        }
    }
}

/// The border point of `board` nearest the centre of its top edge, or that centre when the board
/// has no border.
private func topCentre(_ board: Board) -> Point {
    topPoint(board, board.width / 2)
}

/// The border point of `board` nearest point `x` of its top edge, or that point when the board has
/// no border.
private func topPoint(_ board: Board, _ x: UInt16) -> Point {
    let point = Point(x: x, y: 0)
    return nearestBorderPoint(board, point) ?? point
}

/// The `index`th of `count` points spread evenly across `width`, the ends excluded: `width *
/// (index + 1) / (count + 1)`, rounded down.
private func spread(_ width: UInt16, _ index: Int, _ count: Int) -> UInt16 {
    let point = Int(width) * (index + 1) / (count + 1)
    return UInt16(exactly: point) ?? width
}

/// The border point of `board` the fewest lattice steps (the Manhattan distance) from `point`, the
/// first in reading order among equally near ones; `nil` when the board has no border.
func nearestBorderPoint(_ board: Board, _ point: Point) -> Point? {
    var nearest: (point: Point, distance: UInt32)?
    for y in 0 ... board.height {
        for x in 0 ... board.width {
            let candidate = Point(x: x, y: y)
            guard board.isBorder(candidate) else { continue }
            let distance = UInt32(point.x.distance(to: candidate.x).magnitude)
                + UInt32(point.y.distance(to: candidate.y).magnitude)
            if nearest.map({ distance < $0.distance }) ?? true {
                nearest = (candidate, distance)
            }
        }
    }
    return nearest?.point
}
