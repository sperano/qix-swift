// The controls the app reads, a keyboard, game pads and the touch screen, and their sampling into
// the core's `InputState` once a frame: qix-rs's `crates/qix/src/input.rs` and `bindings.rs`, with
// its keys fixed, and the touch controls, which qix-rs does not have.

/// What a key or a game pad button does: a held control or a press.
public enum Control: Hashable, Sendable, CaseIterable {
    case up, down, left, right, fast, slow, confirm, pause

    /// The direction controls in priority order, each with its direction: when several are held,
    /// the first one wins.
    public static let dirs: [(control: Self, dir: Dir)] = [
        (.up, .up), (.down, .down), (.left, .left), (.right, .right),
    ]

    /// The control that holds `dir`.
    public init(_ dir: Dir) {
        switch dir {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        }
    }
}

/// The controls held on the keyboard, on a game pad and on the touch screen, and the presses since
/// the last `sample`.
///
/// A control held on several devices counts once; a press is a control going down while it was not
/// held, so a key repeat or a second device holding it too is no press.
public struct Controls: Hashable, Sendable {
    private var keys: Set<Control> = []
    private var pad: Set<Control> = []
    private var touch: Set<Control> = []
    private var presses: Set<Control> = []

    /// Nothing held or pressed.
    public init() {}

    /// The controls held on any device.
    public var held: Set<Control> {
        keys.union(pad).union(touch)
    }

    /// The key of `control` went down.
    public mutating func keyDown(_ control: Control) {
        if !held.contains(control) {
            presses.insert(control)
        }
        keys.insert(control)
    }

    /// The key of `control` went up.
    public mutating func keyUp(_ control: Control) {
        keys.remove(control)
    }

    /// Every key went up: the keyboard's presses were cancelled, or the app left the foreground,
    /// where the releases do not reach it.
    public mutating func releaseKeys() {
        keys.removeAll()
    }

    /// Drops the presses not sampled yet.
    public mutating func dropPresses() {
        presses.removeAll()
    }

    /// The game pad holds `controls` now, as polled this frame: the ones no device held before are
    /// pressed.
    public mutating func setPad(_ controls: Set<Control>) {
        presses.formUnion(controls.subtracting(held))
        pad = controls
    }

    /// The touch controls hold `controls` now (`TouchControls.held`): the ones no device held
    /// before are pressed.
    public mutating func setTouch(_ controls: Set<Control>) {
        presses.formUnion(controls.subtracting(held))
        touch = controls
    }

    /// `control` was pressed and released at once: a tap on the screen or on a button.
    public mutating func press(_ control: Control) {
        presses.insert(control)
    }

    /// One frame's controls: the held direction (the first of `Control.dirs`), the held draw
    /// buttons, and confirm and pause when pressed since the last sample, which clears the presses.
    public mutating func sample() -> InputState {
        let held = held
        let input = InputState(
            dir: Control.dirs.first { held.contains($0.control) }?.dir,
            fast: held.contains(.fast),
            slow: held.contains(.slow),
            confirm: presses.contains(.confirm),
            pause: presses.contains(.pause)
        )
        presses.removeAll()
        return input
    }
}

/// A game pad's controls as one poll reads them: its stick or D-pad, and its buttons.
public struct PadState: Hashable, Sendable {
    /// Deflection a stick needs along its dominant axis to hold a direction, from 0 to 1.
    public static let deadZone: Float = 0.5

    /// Left (-1) to right (1).
    public var x: Float
    /// Down (-1) to up (1), as GameController reads it.
    public var y: Float
    /// The south face button: draws fast while held, and confirms.
    public var south: Bool
    /// The east face button: draws slow while held.
    public var east: Bool
    /// The menu button: pauses.
    public var menu: Bool

    public init(x: Float = 0, y: Float = 0, south: Bool = false, east: Bool = false, menu: Bool = false) {
        self.x = x
        self.y = y
        self.south = south
        self.east = east
        self.menu = menu
    }

    /// The direction held: along the dominant axis, once it passes `deadZone`; none at a tie.
    public var dir: Dir? {
        let (across, along) = (abs(x), abs(y))
        if across > along, across >= Self.deadZone {
            return x > 0 ? .right : .left
        } else if along > across, along >= Self.deadZone {
            return y > 0 ? .up : .down
        }
        return nil
    }

    /// The controls the pad holds.
    public var controls: Set<Control> {
        var controls: Set<Control> = []
        if let dir {
            controls.insert(Control(dir))
        }
        if south {
            controls.formUnion([.fast, .confirm])
        }
        if east {
            controls.insert(.slow)
        }
        if menu {
            controls.insert(.pause)
        }
        return controls
    }
}
