// The player's controls, as the front end hands them to the core.

/// The controls one `Game.tick` sees.
///
/// `dir`, `fast` and `slow` are held controls: their state at the tick. `confirm` and `pause` are
/// presses: true for the one tick that follows the key press, so a press is neither lost nor
/// repeated whatever the frame rate.
public struct InputState: Hashable, Sendable {
    /// The direction held, if any.
    public var dir: Dir?
    /// The fast-draw button is held.
    public var fast: Bool
    /// The slow-draw button is held.
    public var slow: Bool
    /// Start or confirm was pressed.
    public var confirm: Bool
    /// Pause was pressed.
    public var pause: Bool

    /// The controls given; nothing held or pressed by default, as Rust's `InputState::default()`.
    public init(dir: Dir? = nil, fast: Bool = false, slow: Bool = false, confirm: Bool = false, pause: Bool = false) {
        self.dir = dir
        self.fast = fast
        self.slow = slow
        self.confirm = confirm
        self.pause = pause
    }

    /// The kind of stix the held draw buttons draw, if any: fast when the fast button is held,
    /// whatever the slow one does.
    public var drawKind: DrawKind? {
        if fast {
            .fast
        } else if slow {
            .slow
        } else {
            nil
        }
    }
}

/// A held direction read as repeated presses, as the initials entry and the menus read it: it acts
/// on the tick it is first held, then again after `Tuning.repeatDelayTicks` and every
/// `Tuning.repeatTicks` after that while it stays held.
public struct DirRepeat: Hashable, Sendable {
    private var held: Dir?
    private var heldTicks: UInt32

    /// No direction held.
    public init() {
        self.init(held: nil, heldTicks: 0)
    }

    /// `held` held for `heldTicks` ticks already.
    init(held: Dir?, heldTicks: UInt32) {
        self.held = held
        self.heldTicks = heldTicks
    }

    /// The direction to act on this tick with `dir` held, if any.
    @discardableResult
    public mutating func tick(_ dir: Dir?) -> Dir? {
        if dir != held {
            held = dir
            heldTicks = 0
            return dir
        }
        guard let dir else { return nil }
        heldTicks = heldTicks == .max ? .max : heldTicks + 1
        guard heldTicks >= Tuning.repeatDelayTicks else { return nil }
        let repeated = heldTicks - Tuning.repeatDelayTicks
        return repeated.isMultiple(of: Tuning.repeatTicks) ? dir : nil
    }
}
