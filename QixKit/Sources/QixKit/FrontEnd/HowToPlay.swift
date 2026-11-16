// The rules of the game and its controls as the How to play sheet tells them, with the claim
// threshold, the starting lives and the touch controls the settings choose. qix-rs has no such
// screen: this is the iPhone front end's own.

/// The How to play sheet's text: sections of paragraphs, in reading order.
public struct HowToPlay: Hashable, Sendable {
    /// A titled part of the sheet.
    public struct Section: Hashable, Sendable {
        public var title: String
        public var paragraphs: [String]

        public init(title: String, paragraphs: [String]) {
            self.title = title
            self.paragraphs = paragraphs
        }
    }

    public var sections: [Section]

    /// The sheet for a game played with `settings`: their threshold and starting lives, and their
    /// touch controls on the sides they put them.
    public init(settings: Settings) {
        sections = [
            Self.goal(settings),
            Self.touch(settings),
            Self.keysAndPad,
            Self.dangers,
            Self.scoring(settings),
            Self.levels,
        ]
    }

    /// How to claim the board and clear a level.
    static func goal(_ settings: Settings) -> Section {
        Section(title: "Goal", paragraphs: [
            "Claim \(settings.thresholdPercent)% of the board to clear the level.",
            "Leave the border into the open to draw a stix, then bring it back to the border: "
                + "the area it cuts off from the Qix is claimed. A stix cannot cross itself.",
            "You start with \(lives(settings.startingLivesCount)).",
        ])
    }

    /// The touch controls of `settings`' scheme, on the sides `settings` put them.
    static func touch(_ settings: Settings) -> Section {
        let (stickSide, slowSide) = settings.leftHanded ? ("right", "left") : ("left", "right")
        let steer = switch settings.controlScheme {
        case .stick:
            "Drag the stick \(stickSide) of the board to move along the border; "
                + "push into the open to draw a fast stix."
        case .followTheFinger:
            "Touch the board: the marker heads for the point just above your finger, "
                + "along the border or drawing a fast stix through the open."
        }
        return Section(title: "Touch controls", paragraphs: [
            steer,
            "Hold Slow, \(slowSide) of the board, while moving to draw a slow stix: "
                + "it is slower, but scores x\(Tuning.slowDrawFactor) points.",
            "Tap the board to start or continue. The button above the board pauses.",
        ])
    }

    /// The hardware keyboard's keys and the game pad's buttons.
    static let keysAndPad = Section(title: "Keyboard and controller", paragraphs: [
        "Keyboard: the arrows move, hold Z to draw fast or X to draw slow, Return confirms, Escape pauses.",
        "Controller: the left stick or the D-pad moves, hold A to draw fast or B to draw slow, "
            + "A confirms, Menu pauses.",
    ])

    /// What takes a life, and the Sparx meter.
    static let dangers = Section(title: "Dangers", paragraphs: [
        "The Qix takes a life when it touches your stix or the marker drawing it.",
        "Sparx run along the border and take a life when they reach the marker.",
        "Stop while drawing and a fuse lights at the start of the stix and burns towards the marker; "
            + "move on to put it out.",
        "The Sparx meter above the board counts down. When it runs out, \(Tuning.extraSparx) more Sparx "
            + "come in at the top; when it runs out again, every Sparx turns Super and chases the marker "
            + "along the stix.",
        "After a life is lost, the Sparx cannot hurt you and you cannot draw for "
            + "\(Tuning.respawnGraceTicks / Tuning.tickHz) seconds.",
    ])

    /// What a claim, a level and the score bring, at `settings`' threshold.
    static func scoring(_ settings: Settings) -> Section {
        Section(title: "Scoring", paragraphs: [
            "Each claimed cell scores \(Tuning.pointsPerCell) points times the multiplier, "
                + "x\(Tuning.slowDrawFactor) when the whole stix was drawn slow.",
            "Clearing a level adds \(Numbers.thousands(Tuning.bonusPerPercent)) points for each whole percent "
                + "claimed past \(settings.thresholdPercent)%.",
            "An extra life every \(Numbers.thousands(Tuning.extraLifeEvery)) points, "
                + "up to \(lives(Int(Tuning.maxLives))).",
        ])
    }

    /// The split of the Qix and the levels' difficulty.
    static let levels = Section(title: "Levels", paragraphs: [
        "From level \(Tuning.twoQixFromLevel), two Qix fly. Cut them apart with a stix and the level ends "
            + "at once, without a bonus, but the multiplier rises by one, up to x\(Tuning.maxMultiplier).",
        "Up to level \(Tuning.firstLevel + Tuning.difficultyRampLevels), each level speeds the Qix up and "
            + "shortens the Sparx meter, and every \(Tuning.levelsPerExtraSparx) levels add a Sparx.",
    ])

    /// `count` lives, in words: "1 life", "3 lives".
    static func lives(_ count: Int) -> String {
        count == 1 ? "1 life" : "\(count) lives"
    }
}
