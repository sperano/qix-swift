// The follow-the-finger control scheme: the marker heads for the lattice point a finger aims at on
// the board. qix-rs has no touch controls: this is the iPhone front end's own.

/// Steers the marker towards a target on the board, one direction a tick.
///
/// The target is the lattice point nearest the aim, clamped onto the board's lattice. On the border
/// with the target on the border too, the marker takes the shorter way round the border graph
/// (straight for it when the border does not lead there). Anywhere else it heads straight for the
/// target along one axis, then the other: the dominant one first, the one it heads along kept until
/// the marker is level with the target on it, so a run is an L, not a staircase. A step the core
/// would refuse gives way to the other axis; with both refused, or the target reached, it holds no
/// direction and the marker stops. Every step it holds brings the marker closer to a target that
/// stays put, along the shortest way round on the border, so the marker never loops.
public struct TouchSteering: Equatable, Sendable {
    /// Where the finger aims, in cells from the board's top-left corner; `nil` while no finger
    /// aims.
    public private(set) var aim: Vec2?
    /// The direction held at the last tick.
    private var heading: Dir?
    /// The last way found round the border.
    private var route: BorderRoute?

    /// Nothing aimed at.
    public init() {}

    /// Aims at `aim`, in cells from the board's top-left corner, or at nothing; a NaN coordinate
    /// aims at nothing. Moving the aim keeps the axis the marker heads along.
    public mutating func steer(towards aim: Vec2?) {
        guard let aim, !aim.x.isNaN, !aim.y.isNaN else {
            self = Self()
            return
        }
        self.aim = aim
    }

    /// The lattice point of `board` the aim is nearest, the aim clamped onto the lattice; `nil`
    /// while nothing is aimed at.
    public func target(on board: Board) -> Point? {
        aim.map { Point(x: Self.coordinate($0.x, upTo: board.width), y: Self.coordinate($0.y, upTo: board.height)) }
    }

    /// The direction the marker of `game` takes this tick towards the target; `nil` with no target,
    /// on it, or with every step towards it refused.
    public mutating func dir(_ game: Game) -> Dir? {
        let dir = target(on: game.board).flatMap { target in
            let alongTheBorder = game.marker.state == .onBorder && game.board.isBorder(target)
            return (alongTheBorder ? roundTheBorder(game, to: target) : nil) ?? straight(game, to: target)
        }
        heading = dir
        return dir
    }

    /// The first step of the shortest way along the border from the marker of `game` to `target`.
    private mutating func roundTheBorder(_ game: Game, to target: Point) -> Dir? {
        let pos = game.marker.pos
        if route?.leads(from: pos, on: game.board, to: target) != true {
            route = BorderRoute(game.board, from: pos, to: target)
        }
        return route?.dir(from: pos)
    }

    /// The first step the core allows the marker of `game` towards `target` along the axis held, or
    /// the dominant one (horizontal at a tie), then along the other axis.
    private func straight(_ game: Game, to target: Point) -> Dir? {
        let pos = game.marker.pos
        let (dx, dy) = (Int(target.x) - Int(pos.x), Int(target.y) - Int(pos.y))
        let horizontal: Dir? = dx > 0 ? .right : (dx < 0 ? .left : nil)
        let vertical: Dir? = dy > 0 ? .down : (dy < 0 ? .up : nil)
        let horizontalFirst = switch heading {
        case .left, .right: horizontal != nil || vertical == nil
        case .up, .down: vertical == nil
        case nil: abs(dx) >= abs(dy)
        }
        let order = horizontalFirst ? [horizontal, vertical] : [vertical, horizontal]
        return order.compactMap(\.self).first { Self.allows(game, $0) }
    }

    /// The core moves the marker of `game` one step towards `dir` this tick with a draw button
    /// held: along a border edge, or drawing through free space outside the grace period.
    private static func allows(_ game: Game, _ dir: Dir) -> Bool {
        let marker = game.marker
        if let stix = game.stix {
            return legalStep(marker, stix, game.board, dir) != nil
        }
        if marker.borderStep(game.board, dir) != nil {
            return true
        }
        return game.graceTicks == 0 && legalStep(marker, Stix(start: marker.pos), game.board, dir) != nil
    }

    /// `value` rounded to the nearest whole cell, clamped into `0 ... limit`.
    private static func coordinate(_ value: Float, upTo limit: UInt16) -> UInt16 {
        UInt16(min(max(value.rounded(), 0), Float(limit)))
    }
}

/// The shortest way along the border of a board between two lattice points, as found from its
/// first point.
private struct BorderRoute: Equatable, Sendable {
    /// The board the way was found on: another board's border may run elsewhere.
    let board: Board
    /// Where the way was found from.
    let start: Point
    /// The points of the way, from where it was found from to the target, `[]` when the border
    /// does not lead there.
    let points: [Point]
    let target: Point

    /// The shortest way along `board`'s border from `start` to `target`, the first found in the
    /// order of `Dir.all` among equally short ones.
    init(_ board: Board, from start: Point, to target: Point) {
        self.board = board
        self.start = start
        self.target = target
        var previous = [start: start]
        var queue = [start]
        var next = 0
        while next < queue.count, previous[target] == nil {
            let point = queue[next]
            next += 1
            for (_, neighbour) in board.borderNeighbours(point) where previous[neighbour] == nil {
                previous[neighbour] = point
                queue.append(neighbour)
            }
        }
        var points: [Point] = []
        var point: Point? = previous[target] == nil ? nil : target
        while let current = point {
            points.append(current)
            point = current == start ? nil : previous[current]
        }
        self.points = points.reversed()
    }

    /// The way found still holds for `pos` and `target` on `board`: it was found on that board,
    /// for that target, and from `pos` or through it. A board the claims left as it was compares
    /// equal at once, sharing its cells' storage.
    func leads(from pos: Point, on board: Board, to target: Point) -> Bool {
        self.target == target && (pos == start || points.contains(pos)) && self.board == board
    }

    /// The direction of the step after `pos` on the way; `nil` at its end or off it.
    func dir(from pos: Point) -> Dir? {
        guard let index = points.firstIndex(of: pos), index + 1 < points.count else { return nil }
        return Dir.between(pos, points[index + 1])
    }
}
