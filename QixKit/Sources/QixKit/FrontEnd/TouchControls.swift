// The touch screen's controls, with drawing B of the iPhone port's plan: the stick's direction
// draws fast, the Slow button draws slow. qix-rs has no touch controls: this is the iPhone front
// end's own.

/// The touch control a touch lands on.
public enum TouchControl: Hashable, Sendable {
    /// The floating stick, left of the board, or right of it when left-handed.
    case stick
    /// The Slow button, on the other side of the board.
    case slow
}

/// The floating stick and the Slow button, held by touches tracked by identity, so two thumbs
/// steer and draw at once.
///
/// A touch keeps the control it landed on until it lifts or is cancelled, wherever it moves: the
/// stick follows its own touch off its zone. The stick takes the first touch landing on it; one
/// landing while it is held holds nothing. Any touch on the Slow button holds it.
public struct TouchControls<Touch: Hashable & Sendable>: Equatable, Sendable {
    /// The stick, as its touch moves it.
    public private(set) var stick = FloatingStick()
    private var stickTouch: Touch?
    private var slowTouches: Set<Touch> = []

    /// Nothing touched.
    public init() {}

    /// A touch holds the Slow button.
    public var slowHeld: Bool {
        !slowTouches.isEmpty
    }

    /// `touch` landed on `control` at `point`.
    public mutating func began(_ touch: Touch, on control: TouchControl, at point: Vec2) {
        switch control {
        case .stick:
            guard stickTouch == nil else { return }
            stickTouch = touch
            stick.touchDown(at: point)
        case .slow:
            slowTouches.insert(touch)
        }
    }

    /// `touch` moved to `point`: the stick follows it if it is the stick's.
    public mutating func moved(_ touch: Touch, to point: Vec2) {
        if touch == stickTouch {
            stick.move(to: point)
        }
    }

    /// `touch` lifted or was cancelled: it releases the control it held.
    public mutating func ended(_ touch: Touch) {
        if touch == stickTouch {
            stickTouch = nil
            stick.lift()
        }
        slowTouches.remove(touch)
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
