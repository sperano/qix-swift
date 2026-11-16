// The sound effects the events of the game play: qix-rs's `crates/qix/src/sound.rs`.

/// A sound effect.
public enum Sound: Hashable, Sendable {
    /// One step of the stix, drawn with this kind.
    case draw(DrawKind)
    /// A stix claimed cells.
    case claim
    /// The player lost a life.
    case death
    /// The level is complete.
    case levelComplete
    /// The player earned a life.
    case extraLife

    /// Every sound effect.
    public static let all: [Self] = [.draw(.fast), .draw(.slow), .claim, .death, .levelComplete, .extraLife]

    /// The sounds the events of one tick play, each once, in the order of the first event playing
    /// it. The step of the stix is a background tick: any other sound of the tick plays instead of
    /// it.
    public static func sounds(_ events: [Event]) -> [Self] {
        var sounds: [Self] = []
        for sound in events.compactMap(soundFor) where !sounds.contains(sound) {
            sounds.append(sound)
        }
        if sounds.contains(where: { !$0.isDraw }) {
            sounds.removeAll(where: \.isDraw)
        }
        return sounds
    }

    /// The sound is a step of the stix.
    private var isDraw: Bool {
        if case .draw = self {
            return true
        }
        return false
    }
}

/// The sound `event` plays, if any: the end of the game plays none, the death raised with it does.
public func soundFor(_ event: Event) -> Sound? {
    switch event {
    case let .draw(kind): .draw(kind)
    case .claim: .claim
    case .death: .death
    case .extraLife: .extraLife
    case .levelComplete: .levelComplete
    case .gameOver: nil
    }
}
