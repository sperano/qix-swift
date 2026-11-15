import QixKit

/// The cases `BoardInvariantsTests` plays: random legal input sequences played through
/// `Game.tick(_:)` on small boards, drawn from the game's own `Rng`.
///
/// An input sequence is a list of `Action`s, each read against the game it is played on: a move
/// picks one of the marker's legal moves, a wait holds nothing for a while. A case ends when the
/// actions run out, the game is over, the level is complete or a stix is caught in a dead end.
///
/// qix-rs draws them with proptest; Swift has none, so each strategy is a draw from `Rng` with
/// the same distribution, and a case is drawn from a generator seeded with its own `Case.seed`,
/// which replays it.
enum BoardInvariants {
    /// Dimensions of the boards the cases play on: small, so that random stix reach the border
    /// before they wind themselves into a dead end.
    static let widths: ClosedRange<UInt16> = 8 ... 16
    static let heights: ClosedRange<UInt16> = 6 ... 12

    /// Qix a case plays against: one or two of them.
    static let qixCounts: ClosedRange<Int> = 1 ... 2

    /// Actions a case plays at most.
    static let maxActions = 300

    /// The odds of an action being a move against it being a wait.
    static let moveWeight = 19
    static let waitWeight = 1

    /// Ticks a wait lasts at most: enough for the fuse to be lit and burn.
    static let maxWaitTicks: UInt32 = 3 * Tuning.fuseDelayTicks

    /// Chance that the marker leaves the border when it can.
    static let startDrawChance: Float = 0.3

    /// Chance that a stix keeps its heading when it can: straight runs reach the border more
    /// often than a random walk.
    static let keepHeadingChance: Float = 0.7

    /// Chance of each side of a fair coin: proptest's `any::<bool>()` and a choice between two
    /// equally weighted values.
    static let evenChance: Float = 0.5

    /// Length of each Qix, in playfield units: short enough for the small boards.
    static let qixLength: Float = 1.0

    /// A full turn, in radians: the headings of the Qix are drawn below it.
    static let fullTurn = 2 * Float.pi

    /// The game a case plays: its board, its Qix and its Sparx.
    struct Setup {
        let width: UInt16
        let height: UInt16
        /// The seed of the game's generator.
        let seed: UInt64
        /// The headings of the Qix, in radians: one or two of them, spread along the middle row.
        let qixHeadings: [Float]
        /// Whether the first Sparx starts Super: the second always does, so that one chases along
        /// the stix.
        let firstSuper: Bool

        /// A game on a fresh board, with the highest claim threshold, so the cases claim as much
        /// as they can before the level is complete.
        func game() -> Game {
            let board = Board(width: width, height: height)
            let pair = Sparx.spawnPair(board)
            let (first, second) = (pair[0], pair[1])
            let sparx = [
                Sparx(pos: first.pos, dir: first.dir, kind: firstSuper ? .super : .normal),
                Sparx(pos: second.pos, dir: second.dir, kind: .super),
            ]
            var game = Game(board: board, qix: qix(board), sparx: sparx, rng: Rng(seed: seed))
            game.setClaimThreshold(ClaimThreshold(Tuning.claimThresholdRange.upperBound))
            return game
        }

        /// The Qix, level and `qixLength` long, spread evenly along the middle row of `board`,
        /// each moving at the slowest speed.
        func qix(_ board: Board) -> [Qix] {
            let (width, height) = (Float(board.width), Float(board.height))
            let slots = Float(qixHeadings.count + 1)
            let half = Vec2(x: qixLength * 0.5, y: 0.0)
            return qixHeadings.enumerated().map { slot, heading in
                let centre = Vec2(x: width * Float(slot + 1) / slots, y: height * 0.5)
                let vel = Vec2.fromAngle(heading) * Tuning.qixSpeed.lowerBound
                return Qix(a: centre - half, b: centre + half, vel: vel, spin: 0.0)
            }
        }
    }

    /// One part of an input sequence, read against the game it is played on.
    enum Action {
        /// A step of the marker, held until it moves or dies: one of its legal moves (see
        /// `legalMove(_:_:)`).
        case move(Choice)
        /// Nothing held for this many ticks.
        case wait(UInt32)
    }

    /// What picks a marker step among its legal moves.
    struct Choice {
        /// Picks the direction among the legal ones: proptest's `Index`, see `pickFrom(_:_:)`.
        let pick: UInt64
        /// Leave the border, when the marker can.
        let startDraw: Bool
        /// Keep the stix's heading, when that is legal.
        let keepHeading: Bool
        /// The draw button held for a stix step.
        let kind: DrawKind
    }

    /// A game to play and the input sequence to play on it.
    struct Case {
        /// The seed of the generator the case was drawn from: `init(seed:)` draws it again.
        let seed: UInt64
        let setup: Setup
        let actions: [Action]

        /// The case drawn from a generator seeded with `seed`.
        init(seed: UInt64) {
            var rng = Rng(seed: seed)
            self.seed = seed
            setup = drawSetup(&rng)
            actions = (0 ..< draw(1 ... maxActions, &rng)).map { _ in drawAction(&rng) }
        }
    }

    /// `count` cases, each from the next seed of a generator seeded with `seed`.
    static func cases(_ seed: UInt64, _ count: Int) -> [Case] {
        var seeds = Rng(seed: seed)
        return (0 ..< count).map { _ in Case(seed: seeds.nextU64()) }
    }

    /// A uniform value of `range`.
    static func draw<T: BinaryInteger>(_ range: ClosedRange<T>, _ rng: inout Rng) -> T {
        range.lowerBound + T(rng.below(Int(range.upperBound - range.lowerBound) + 1))
    }

    /// `true` with `chance`: proptest's `prop::bool::weighted`.
    static func weighted(_ chance: Float, _ rng: inout Rng) -> Bool {
        rng.nextF32() < chance
    }

    static func drawSetup(_ rng: inout Rng) -> Setup {
        let width = draw(widths, &rng)
        let height = draw(heights, &rng)
        let seed = rng.nextU64()
        let headings = (0 ..< draw(qixCounts, &rng)).map { _ in rng.rangeF32(0, fullTurn) }
        let firstSuper = weighted(evenChance, &rng)
        return Setup(width: width, height: height, seed: seed, qixHeadings: headings, firstSuper: firstSuper)
    }

    static func drawAction(_ rng: inout Rng) -> Action {
        guard rng.below(moveWeight + waitWeight) < moveWeight else {
            return .wait(draw(1 ... maxWaitTicks, &rng))
        }
        let pick = rng.nextU64()
        let startDraw = weighted(startDrawChance, &rng)
        let keepHeading = weighted(keepHeadingChance, &rng)
        let kind: DrawKind = weighted(evenChance, &rng) ? .fast : .slow
        return .move(Choice(pick: pick, startDraw: startDraw, keepHeading: keepHeading, kind: kind))
    }

    /// One marker step: the direction held, with the draw button, if any.
    struct Move {
        let dir: Dir
        let draw: DrawKind?

        var input: InputState {
            InputState(dir: dir, fast: draw == .fast, slow: draw == .slow)
        }
    }

    /// The legal move `choice` picks for `game`'s marker: a step of its stix, a step off the
    /// border into free space or a step along the border; or `nil` when its stix is caught in a
    /// dead end.
    static func legalMove(_ game: Game, _ choice: Choice) throws -> Move? {
        let (marker, board) = (game.marker, game.board)
        let draw = choice.kind
        if let stix = game.stix {
            let moves = legalMoves(marker, stix, board)
            let points = stix.points
            let heading = points.count >= 2 ? Dir.between(points[points.count - 2], points[points.count - 1]) : nil
            let kept = heading.flatMap { choice.keepHeading && moves.contains($0) ? $0 : nil }
            guard let dir = kept ?? pickFrom(moves, choice.pick) else { return nil }
            return Move(dir: dir, draw: draw)
        }
        // The marker cannot draw during the grace period after a death.
        let starts = game.graceTicks == 0 ? legalMoves(marker, Stix(start: marker.pos), board) : []
        if let dir = pickFrom(starts, choice.pick), choice.startDraw {
            return Move(dir: dir, draw: draw)
        }
        let walks = board.borderNeighbours(marker.pos).map(\.dir)
        guard let dir = pickFrom(walks, choice.pick) else {
            throw Failure("a border point has border edges: \(marker) has none")
        }
        return Move(dir: dir, draw: nil)
    }

    /// The item of `items` that `pick` selects, or `nil` when there is none: like proptest's
    /// `Index`, the high bits of `pick` scaled by the count.
    static func pickFrom<T>(_ items: [T], _ pick: UInt64) -> T? {
        guard !items.isEmpty else { return nil }
        return items[Int(pick.multipliedFullWidth(by: UInt64(items.count)).high)]
    }

    /// A case that failed: an invariant broken, or an action that did not play as it should.
    struct Failure: Error, CustomStringConvertible {
        let description: String

        init(_ description: String) {
            self.description = description
        }
    }

    /// Fails the case with `message` unless `condition` holds: proptest's `prop_assert!`.
    static func ensure(_ condition: Bool, _ message: @autoclosure () -> String) throws {
        guard condition else { throw Failure(message()) }
    }
}
