// The touch screen's controls, with drawing B of the iPhone port's plan: the stick's direction
// draws fast, the Slow button draws slow. qix-rs has no touch controls: this is the iPhone front
// end's own.

/// The touch control a touch lands on.
public enum TouchControl: Equatable, Sendable {
    /// The floating stick, left of the board, or right of it when left-handed.
    case stick
    /// The Slow button, on the other side of the board.
    case slow
    /// The board, where it is on the screen, which a finger aims at when following the finger.
    case board(BoardFrame)
}

/// Where the board is on the screen, in points, y down, as touches report them.
public struct BoardFrame: Equatable, Sendable {
    /// How far above the finger it aims, in points: the finger covers neither the marker nor the
    /// Qix around it.
    public static let fingerLift: Float = 40

    /// The board's top-left corner.
    public var origin: Vec2
    /// The points a cell takes.
    public var pointsPerCell: Float

    public init(origin: Vec2, pointsPerCell: Float) {
        self.origin = origin
        self.pointsPerCell = pointsPerCell
    }

    /// Where a finger at `point` aims, in cells from the board's top-left corner: `fingerLift`
    /// above it.
    public func aim(at point: Vec2) -> Vec2 {
        (point - origin - Vec2(x: 0, y: Self.fingerLift)) * (1 / pointsPerCell)
    }
}

/// The floating stick, the Slow button and the board, held by touches tracked by identity, so two
/// thumbs steer and draw at once.
///
/// A touch keeps the control it landed on until it lifts or is cancelled, wherever it moves: the
/// stick follows its own touch off its zone, and the board's aim its own touch off the board. The
/// stick and the board each take the first touch landing on them; one landing while they are held
/// holds nothing. Any touch on the Slow button holds it. A touch landing on the board out of play
/// aims at nothing: it is a tap, to start or continue (see `ended`).
public struct TouchControls<Touch: Hashable & Sendable>: Equatable, Sendable {
    /// The stick, as its touch moves it.
    public private(set) var stick = FloatingStick()
    /// Where the board's touch aims (`BoardFrame.aim(at:)`), `nil` while no touch aims.
    public private(set) var aim: Vec2?
    private var stickTouch: Touch?
    private var slowTouches: Set<Touch> = []
    private var boardTouch: BoardTouch?
    private var boardTaps: Set<Touch> = []

    /// The touch aiming on the board, and where the board was when it landed.
    private struct BoardTouch: Equatable, Sendable {
        let touch: Touch
        let frame: BoardFrame
    }

    /// Nothing touched.
    public init() {}

    /// A touch holds the Slow button.
    public var slowHeld: Bool {
        !slowTouches.isEmpty
    }

    /// `touch` landed on `control` at `point`, with a game in play or not: on the board, it aims in
    /// play and is a tap out of it.
    public mutating func began(_ touch: Touch, on control: TouchControl, at point: Vec2, inPlay: Bool = true) {
        switch control {
        case .stick:
            guard stickTouch == nil else { return }
            stickTouch = touch
            stick.touchDown(at: point)
        case .slow:
            slowTouches.insert(touch)
        case let .board(frame) where inPlay:
            guard boardTouch == nil else { return }
            boardTouch = BoardTouch(touch: touch, frame: frame)
            aim = frame.aim(at: point)
        case .board:
            boardTaps.insert(touch)
        }
    }

    /// `touch` moved to `point`: the stick or the board's aim follows it if it is theirs.
    public mutating func moved(_ touch: Touch, to point: Vec2) {
        if touch == stickTouch {
            stick.move(to: point)
        }
        if let boardTouch, touch == boardTouch.touch {
            aim = boardTouch.frame.aim(at: point)
        }
    }

    /// `touch` lifted: it releases the control it held. Returns whether it was a tap on the board:
    /// it landed there out of play.
    @discardableResult
    public mutating func ended(_ touch: Touch) -> Bool {
        if touch == stickTouch {
            stickTouch = nil
            stick.lift()
        }
        if touch == boardTouch?.touch {
            boardTouch = nil
            aim = nil
        }
        slowTouches.remove(touch)
        return boardTaps.remove(touch) != nil
    }

    /// `touch` was cancelled: it releases the control it held, as when it lifts, but it is no tap.
    public mutating func cancelled(_ touch: Touch) {
        ended(touch)
    }

    /// The controls held: the stick's direction with fast, or with slow while the Slow button is
    /// held, and slow alone with no direction. Fast is not held with slow: `InputState.drawKind`
    /// lets fast win, so the Slow button would draw nothing slow.
    public var held: Set<Control> {
        var held: Set<Control> = []
        if let dir = stick.dir {
            held.insert(Control(dir))
            if !slowHeld {
                held.insert(.fast)
            }
        }
        if slowHeld {
            held.insert(.slow)
        }
        return held
    }
}
