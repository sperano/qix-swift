// The haptics of play, which stand in on a touch screen for the feel of a key. qix-rs has none:
// this is the iPhone front end's own.

/// What the player feels.
public enum Haptic: Hashable, Sendable {
    /// A light tick: the direction held changed, or the marker left the border.
    case tick
    /// A bump: a step was refused (a corner, a dead end, off the border with no draw).
    case bump
    /// A stix claimed cells, or completed the level.
    case success
    /// The player lost a life.
    case error
}

/// The haptic each tick of play raises, from the core's events and the direction the tick held: at
/// most one a tick, the strongest (`error`, then `success`, then `bump`, then `tick`). A refused
/// step bumps once per hold of its direction: holding a direction the core keeps refusing does not
/// bump again until the direction changes.
public struct HapticCues: Hashable, Sendable {
    /// The direction the last tick of play held.
    private var held: Dir?
    /// A step towards `held` was refused and bumped since `held` was first held.
    private var bumped = false

    /// Nothing held.
    public init() {}

    /// The haptic of the tick of `session` with `input` that found the marker at `marker`; none when
    /// that tick did not tick the game (`Session.played`), which also forgets the direction held.
    public mutating func cue(_ input: InputState, from marker: Marker, to session: Session) -> Haptic? {
        guard session.played else {
            self = Self()
            return nil
        }
        let turned = input.dir != nil && input.dir != held
        if input.dir != held {
            held = input.dir
            bumped = false
        }
        let game = session.game
        if game.events.contains(where: Self.isDeath) {
            return .error
        }
        if game.events.contains(where: Self.isSuccess) {
            return .success
        }
        if !bumped, Self.refusedStep(input, from: marker, to: game) {
            bumped = true
            return .bump
        }
        let leftBorder = marker.state == .onBorder && game.marker.state == .drawing
        return turned || leftBorder ? .tick : nil
    }

    /// The tick of `game` with `input`, which found the marker at `marker`, was due to step the
    /// marker and the core refused the step: a direction is held, the marker is not standing still
    /// on its stix with no draw button, the step count started again (`Game.markerHeldTicks`) and
    /// the marker stayed where it was.
    static func refusedStep(_ input: InputState, from marker: Marker, to game: Game) -> Bool {
        let standing = marker.state == .drawing && input.drawKind == nil
        return input.dir != nil && !standing && game.markerHeldTicks == 0 && game.marker.pos == marker.pos
    }

    private static func isDeath(_ event: Event) -> Bool {
        if case .death = event {
            return true
        }
        return false
    }

    private static func isSuccess(_ event: Event) -> Bool {
        switch event {
        case .claim, .levelComplete: true
        case .draw, .death, .extraLife, .gameOver: false
        }
    }
}
