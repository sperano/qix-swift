// The attract-mode demo: a scripted sequence of inputs replayed through a real `Game`.

/// Lattice steps the marker walks along the border between two rectangles.
private let hop: UInt32 = 5

/// Ticks the demo waits before its first move: two seconds.
private let openingTicks: UInt32 = 2 * Tuning.tickHz

/// Ticks the marker rests after each claim: half a second.
private let restTicks: UInt32 = Tuning.tickHz / 2

/// Ticks the demo holds its last claim before it ends: a second and a half.
private let closingTicks: UInt32 = 3 * Tuning.tickHz / 2

/// One part of a demo script: an input held for a number of ticks.
public struct DemoStep: Hashable, Sendable {
    /// The input every tick of the step sees.
    public var input: InputState
    /// How many ticks the input is held.
    public var ticks: UInt32

    /// `input` held for `ticks` ticks.
    public init(input: InputState, ticks: UInt32) {
        self.input = input
        self.ticks = ticks
    }

    /// No control held for `ticks` ticks.
    public static func idle(_ ticks: UInt32) -> Self {
        Self(input: InputState(), ticks: ticks)
    }

    /// `dir` held, without a draw button, for `ticks` ticks.
    public static func walk(_ dir: Dir, _ ticks: UInt32) -> Self {
        Self(input: InputState(dir: dir), ticks: ticks)
    }

    /// `dir` held with the draw button of `kind` for `ticks` ticks.
    public static func draw(_ dir: Dir, _ kind: DrawKind, _ ticks: UInt32) -> Self {
        Self(input: InputState(dir: dir, fast: kind == .fast, slow: kind == .slow), ticks: ticks)
    }
}

/// A walk of `steps` lattice steps along the border.
private func walk(_ dir: Dir, _ steps: UInt32) -> DemoStep {
    .walk(dir, steps * Tuning.markerStepTicks)
}

/// A fast draw of `steps` lattice steps.
private func fast(_ dir: Dir, _ steps: UInt32) -> DemoStep {
    .draw(dir, .fast, steps * Tuning.markerStepTicks)
}

/// A slow draw of `steps` lattice steps.
private func slow(_ dir: Dir, _ steps: UInt32) -> DemoStep {
    .draw(dir, .slow, steps * Tuning.slowStepTicks)
}

/// A game replaying a script of inputs, one step of the script per tick.
public struct Demo: Sendable {
    /// Height of the rectangles the demo claims, in cells.
    static let boxHeight: UInt32 = 45

    /// Width of the first two rectangles the demo claims, in cells.
    static let boxWidth: UInt32 = 25

    /// Width of the last rectangle, from the border to the left edge, in cells.
    static let lastBoxWidth: UInt32 = 20

    /// The demo's inputs, for a `Game` seeded with `Tuning.demoSeed`. The marker starts at the
    /// centre of the bottom edge and claims three rectangles along it, working leftwards: a fast
    /// one `boxWidth` cells wide and `boxHeight` high, a slow one of the same size and a slow one
    /// `lastBoxWidth` wide against the left edge. A sixth of the board is claimed at the end.
    public static let demoScript: [DemoStep] = [
        .idle(openingTicks),
        fast(.up, boxHeight),
        fast(.left, boxWidth),
        fast(.down, boxHeight),
        .idle(restTicks),
        walk(.left, hop),
        slow(.up, boxHeight),
        slow(.left, boxWidth),
        slow(.down, boxHeight),
        .idle(restTicks),
        walk(.left, hop),
        slow(.up, boxHeight),
        slow(.left, lastBoxWidth),
        .idle(closingTicks),
    ]

    /// The game being played.
    public private(set) var game: Game
    private let script: [DemoStep]
    /// The index of the step being replayed.
    private var step: Int
    /// Ticks of that step already run.
    private var stepTicks: UInt32

    /// The demo of `demoScript` on a new game seeded with `Tuning.demoSeed`.
    public init() {
        self.init(game: Game(rng: Rng(seed: Tuning.demoSeed)), script: Self.demoScript)
    }

    /// A demo replaying `script` on `game`.
    public init(game: Game, script: [DemoStep]) {
        self.game = game
        self.script = script
        step = 0
        stepTicks = 0
        skipEmptySteps()
    }

    /// Ticks the game once with the input of the current step and moves on in the script. Does
    /// nothing once the demo is finished.
    public mutating func tick() {
        if isFinished {
            return
        }
        let current = script[step]
        game.tick(current.input)
        stepTicks += 1
        if stepTicks >= current.ticks {
            step += 1
            stepTicks = 0
            skipEmptySteps()
        }
    }

    /// The script has run out, or the game is over or its level complete.
    public var isFinished: Bool {
        step >= script.count || game.isOver || game.isLevelComplete
    }

    /// Moves past steps that hold their input for no tick.
    private mutating func skipEmptySteps() {
        while step < script.count, script[step].ticks == 0 {
            step += 1
        }
    }
}
