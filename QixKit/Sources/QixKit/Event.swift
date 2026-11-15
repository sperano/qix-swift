// What a tick of the game reports to the application.

/// Something that happened during a tick.
public enum Event: Equatable, Sendable {
    /// The marker drew one more step of the stix, with this kind; the step that closes the stix
    /// included.
    case draw(DrawKind)
    /// A stix closed and claimed cells, scored before any `Event.extraLife` or
    /// `Event.levelComplete` they bring.
    ///
    /// - `cells`: the cells the stix claimed.
    /// - `kind`: how the claimed cells were drawn.
    case claim(cells: Int, kind: DrawKind)
    /// The player lost a life.
    case death(DeathCause)
    /// The score crossed a multiple of `Tuning.extraLifeEvery` and the player earned a life: one
    /// event per life.
    case extraLife
    /// The player lost the last life, right after its `Event.death`: the game no longer ticks.
    case gameOver
    /// A claim took the board to the claim threshold or above, and the level bonus was scored, or
    /// a stix split the Qix apart, which scores no bonus but raises the multiplier: the game no
    /// longer ticks.
    ///
    /// - `fraction`: the board's claimed fraction after the claim, from 0 to 1.
    /// - `bonus`: the level bonus scored, zero after a split.
    /// - `split`: the stix left the Qix in different free areas.
    case levelComplete(fraction: Float, bonus: UInt32, split: Bool)
}

/// What killed the player.
public enum DeathCause: Hashable, Sendable {
    /// The Qix touched the stix or the drawing marker.
    case qix
    /// A Sparx reached the marker.
    case sparx
    /// The fuse burnt along the stix to the marker.
    case fuse
}
