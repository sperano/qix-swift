import QixKit
import XCTest

/// Board invariants as seeded properties: the random legal input sequences of
/// `BoardInvariants.Case` played through `Game.tick(_:)` on small boards, with every invariant
/// checked after every tick.
///
/// qix-rs checks them with proptest. Swift has none, so the cases are a fixed sample drawn from
/// `sampleSeed`, the same on every run and platform; there is no shrinking either, so a failure
/// names the case's index, its seed (`BoardInvariants.Case(seed:)` replays it) and its setup.
final class BoardInvariantsTests: XCTestCase {
    func testEveryTickKeepsTheInvariants() {
        for (index, sample) in BoardInvariants.cases(sampleSeed, invariantCases).enumerated() {
            do {
                _ = try playCase(sample.setup, sample.actions, checkInvariants)
            } catch {
                XCTFail("case \(index) (seed \(sample.seed)) on \(sample.setup): \(error)")
            }
        }
    }

    func testTheCasesExerciseWhatTheInvariantsCheck() throws {
        var total = Stats()
        for sample in BoardInvariants.cases(sampleSeed, coverageCases) {
            let stats = try playCase(sample.setup, sample.actions) { _, _, _ in }
            total = total.add(stats)
        }
        XCTAssertGreaterThanOrEqual(total.claims, minClaims, "\(total)")
        XCTAssertGreaterThanOrEqual(total.chasingTicks, minChasingTicks, "\(total)")
        XCTAssertGreaterThanOrEqual(total.levelsComplete, minLevelsComplete, "\(total)")
        let eachCause = total.deaths.allSatisfy { $0 >= minDeathsByEachCause }
        XCTAssertTrue(eachCause, "\(total)")
    }
}

/// The seed of the generator the seeds of the sampled cases come from.
private let sampleSeed: UInt64 = 0x51C5_B0A2_D1A7_0001

/// Cases the invariant test samples: proptest's default.
private let invariantCases = 256

/// Spacing of the points the free-cell check samples along a Qix, independently of the cell walk
/// the Qix moves by.
private let sampleSpacing: Float = 0.05

/// Cases the coverage test samples: the first ones of the invariant test's sample. Twice qix-rs's
/// 64: the first 64 of this sample claim 43 times and complete no level, short of `minClaims` and
/// `minLevelsComplete`, while the first 128 claim 96 times and complete 3 levels.
private let coverageCases = 128

/// What the cases of `coverageCases` must have done at least, for the invariants to have been put
/// to the test.
private let minClaims: UInt32 = 50
private let minChasingTicks: UInt32 = 1
private let minLevelsComplete: UInt32 = 1
private let minDeathsByEachCause: UInt32 = 1

/// The causes of death, in the order of `Stats.deaths`.
private let deathCauses: [DeathCause] = [.qix, .sparx, .fuse]

/// What the ticks of one or more cases did: enough of it shows that the invariants were put to
/// the test.
private struct Stats {
    var claims: UInt32 = 0
    /// Ticks after which a Sparx stood off the border, on the stix.
    var chasingTicks: UInt32 = 0
    var levelsComplete: UInt32 = 0
    /// Deaths by the Qix, the Sparx and the fuse.
    var deaths = [UInt32](repeating: 0, count: deathCauses.count)

    /// Counts what the last tick of `game` did.
    mutating func record(_ game: Game) {
        for event in game.events {
            switch event {
            case .claim: claims += 1
            case .levelComplete: levelsComplete += 1
            case let .death(cause): deaths[deathIndex(cause)] += 1
            case .draw, .extraLife, .gameOver: break
            }
        }
        let board = game.board
        let chasing = game.sparx.contains { !board.isBorder($0.pos) }
        chasingTicks += chasing ? 1 : 0
    }

    func add(_ other: Self) -> Self {
        Self(
            claims: claims + other.claims,
            chasingTicks: chasingTicks + other.chasingTicks,
            levelsComplete: levelsComplete + other.levelsComplete,
            deaths: zip(deaths, other.deaths).map(+)
        )
    }
}

/// The index of `cause` in `Stats.deaths`.
private func deathIndex(_ cause: DeathCause) -> Int {
    switch cause {
    case .qix: 0
    case .sparx: 1
    case .fuse: 2
    }
}

/// An invariant check, handed the number of claimed cells before the tick and after it, and the
/// game after it. The harness counts the cells once a tick, the count after one tick being the
/// count before the next: counting them is most of a debug run's time.
private typealias Check = (_ claimedBefore: Int, _ claimedAfter: Int, _ game: Game) throws -> Void

/// The number of claimed cells on `board`.
private func claimedCells(_ board: Board) -> Int {
    var count = 0
    for y in 0 ..< Int32(board.height) {
        for x in 0 ..< Int32(board.width) where board.cell(x: x, y: y).isClaimed {
            count += 1
        }
    }
    return count
}

/// Whether the last tick of `game` killed the marker.
private func died(_ game: Game) -> Bool {
    game.events.contains { event in
        if case .death = event { return true }
        return false
    }
}

/// A case being played: its game, what its ticks did so far and the check run after each.
private struct Play {
    var game: Game
    var stats = Stats()
    /// The number of claimed cells on the board of `game`.
    var claimed: Int
    let check: Check

    init(_ game: Game, _ check: @escaping Check) {
        self.game = game
        claimed = claimedCells(game.board)
        self.check = check
    }

    /// Ticks `game` once with `input`, then runs `check` on it.
    mutating func tick(_ input: InputState) throws {
        let claimedBefore = claimed
        game.tick(input)
        claimed = claimedCells(game.board)
        stats.record(game)
        try check(claimedBefore, claimed, game)
    }

    /// Holds `step` until the marker moves or dies; a legal move that does neither within the
    /// slowest step fails the case.
    mutating func playMove(_ step: BoardInvariants.Move) throws {
        let from = game.marker.pos
        for _ in 0 ..< Tuning.slowStepTicks {
            try tick(step.input)
            if died(game) || game.marker.pos != from { return }
        }
        throw BoardInvariants.Failure("legal move \(step) from \(from) did not step")
    }
}

/// Plays `actions` on the game of `setup`, running `check` after every tick, until the game is
/// over, its level complete or its stix caught in a dead end.
private func playCase(
    _ setup: BoardInvariants.Setup, _ actions: [BoardInvariants.Action], _ check: @escaping Check
) throws -> Stats {
    var play = Play(setup.game(), check)
    cases: for action in actions {
        if play.game.isOver || play.game.isLevelComplete { break }
        switch action {
        case let .move(choice):
            guard let step = try BoardInvariants.legalMove(play.game, choice) else { break cases }
            try play.playMove(step)
        case let .wait(ticks):
            for _ in 0 ..< ticks {
                try play.tick(InputState())
            }
        }
    }
    return play.stats
}

/// Claimed cells never become free, and the claimed fraction is the claimed share of the cells.
private func checkClaims(_ claimedBefore: Int, _ claimed: Int, _ game: Game) throws {
    let board = game.board
    try BoardInvariants.ensure(claimed >= claimedBefore, "claimed cells \(claimedBefore) -> \(claimed)")
    let cells = Int(board.width) * Int(board.height)
    // Both sides round the same quotient of two small integers, so they are equal to the bit.
    let share = Float(claimed) / Float(cells)
    let fraction = board.claimedFraction()
    try BoardInvariants.ensure(fraction == share, "claimed fraction \(fraction) != \(claimed) / \(cells)")
}

/// A stix exists exactly while the marker draws, and a marker that does not draw is on the
/// border: no stix is left after a close.
private func checkMarker(_ game: Game) throws {
    let marker = game.marker
    let drawing = marker.state == .drawing
    try BoardInvariants.ensure((game.stix != nil) == drawing, "\(marker) with stix \(String(describing: game.stix))")
    if !drawing {
        try BoardInvariants.ensure(game.board.isBorder(marker.pos), "\(marker) off the border")
    }
}

/// Every point sampled along each Qix, and the cell under its midpoint, is on a free cell.
private func checkQix(_ game: Game) throws {
    let board = game.board
    for qix in game.qix {
        let span = qix.b - qix.a
        let samples = UInt32(max((span.length / sampleSpacing).rounded(.up), 1))
        for i in 0 ... samples {
            let point = qix.a + span * (Float(i) / Float(samples))
            let cell = board.cell(x: cellCoordinate(point.x), y: cellCoordinate(point.y))
            try BoardInvariants.ensure(cell == .free, "\(cell) at \(point) of \(qix)")
        }
        let (x, y) = qix.cell
        let mid = board.cell(x: Int32(x), y: Int32(y))
        try BoardInvariants.ensure(mid == .free, "\(mid) at the midpoint of \(qix)")
    }
}

/// `value` rounded down to a cell coordinate, saturating like Rust's `as i32`, which takes NaN
/// to 0.
private func cellCoordinate(_ value: Float) -> Int32 {
    let floored = value.rounded(.down)
    guard !floored.isNaN else { return 0 }
    guard floored < Float(Int32.max) else { return .max }
    return floored > Float(Int32.min) ? Int32(floored) : .min
}

/// Every Sparx is on the border, or chasing along the stix.
private func checkSparx(_ game: Game) throws {
    for sparx in game.sparx {
        let onBorder = game.board.isBorder(sparx.pos)
        let chasing = game.stix.map { sparx.chasesAlong($0) } ?? false
        try BoardInvariants.ensure(onBorder || chasing, "\(sparx) off the border and the stix")
    }
}

/// Every invariant of the game after a tick.
private func checkInvariants(_ claimedBefore: Int, _ claimedAfter: Int, _ game: Game) throws {
    try checkClaims(claimedBefore, claimedAfter, game)
    try checkMarker(game)
    try checkQix(game)
    try checkSparx(game)
}
