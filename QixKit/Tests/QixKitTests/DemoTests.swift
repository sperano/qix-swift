import XCTest
@testable import QixKit

/// Seed of the games the custom-script tests play.
private let demoTestSeed: UInt64 = 1_194

/// Ticks of the idle step of the short scripts.
private let idleTicks: UInt32 = 5

/// Steps of the stix up the middle column of `shortGame`.
private let shortStixSteps: UInt32 = 3

/// Dimensions of the small board of the short-script tests.
private let shortW: UInt16 = 8
private let shortH: UInt16 = 3

/// Lattice steps of the slow draws of `Demo.demoScript`: up, across and down the second rectangle,
/// then up and across the last one.
private let slowSteps = 3 * Demo.boxHeight + Demo.boxWidth + Demo.lastBoxWidth

/// The claimed fraction of the board at the end of `Demo.demoScript`: a sixth, as its
/// documentation says.
private let demoClaimed: ClosedRange<Float> = 0.15 ... 0.18

/// The length of `Demo.demoScript`, in seconds.
private let demoSeconds: ClosedRange<Float> = 20 ... 30

/// A script that completes the level of `shortGame`, then idles.
private let shortScript: [DemoStep] = [
    .draw(.up, .fast, shortStixSteps * Tuning.markerStepTicks),
    .idle(idleTicks),
]

/// A script of one idle step.
private let idleScript: [DemoStep] = [.idle(idleTicks)]

/// A script of an empty step between two idle ones.
private let emptyStepScript: [DemoStep] = [.idle(0), .idle(idleTicks), .idle(0)]

/// A script of idle ticks, longer than the game the Sparx of `sparxGame` needs to take every life.
private let longIdleScript: [DemoStep] = [.idle(100_000)]

/// A small game with a short Qix in its top-left cell: the stix up the middle column claims the
/// right half, which completes the level at the lowest claim threshold.
private func shortGame() -> Game {
    var game = sparxFreeGame()
    game.setClaimThreshold(ClaimThreshold(0))
    return game
}

/// A game whose Sparx stands next to the marker and kills it again and again.
private func sparxGame() -> Game {
    let sparx = Sparx(pos: Point(x: shortW / 2 + 1, y: shortH), dir: .left, kind: .normal)
    return Game(
        board: Board(width: shortW, height: shortH),
        qix: [qixAt((0, 0))],
        sparx: [sparx],
        rng: Rng(seed: demoTestSeed)
    )
}

/// A game no Sparx can kill in.
private func sparxFreeGame() -> Game {
    Game(board: Board(width: shortW, height: shortH), qix: [qixAt((0, 0))], sparx: [], rng: Rng(seed: demoTestSeed))
}

/// Ticks `demo` to its end and returns the deaths it saw: qix-rs's `run`, renamed since `XCTestCase.run()`
/// hides a global of that name.
@discardableResult
private func runToEnd(_ demo: inout Demo) -> Int {
    var deaths = 0
    while !demo.isFinished {
        demo.tick()
        deaths += demo.game.events.count { if case .death = $0 { true } else { false } }
    }
    return deaths
}

/// The cells of `game`'s board claimed with `kind`.
private func claimed(_ game: Game, _ kind: DrawKind) -> Int {
    let board = game.board
    let cells = (0 ..< Int32(Tuning.boardH)).flatMap { y in (0 ..< Int32(Tuning.boardW)).map { x in (x, y) } }
    return cells.count { board.cell(x: $0.0, y: $0.1) == .claimed(kind) }
}

private func scriptTicks(_ script: [DemoStep]) -> UInt64 {
    script.reduce(0) { $0 + UInt64($1.ticks) }
}

final class DemoTests: XCTestCase {
    func testIdleStepHoldsNothing() {
        let step = DemoStep.idle(idleTicks)

        XCTAssertEqual(step.input, InputState())
        XCTAssertEqual(step.ticks, idleTicks)
    }

    func testWalkStepHoldsOnlyTheDirection() {
        let step = DemoStep.walk(.left, idleTicks)

        XCTAssertEqual(step.input, InputState(dir: .left))
        XCTAssertEqual(step.ticks, idleTicks)
    }

    func testDrawStepHoldsTheButtonOfItsKind() {
        let fast = DemoStep.draw(.up, .fast, idleTicks).input
        let slow = DemoStep.draw(.up, .slow, idleTicks).input

        XCTAssertEqual(fast, InputState(dir: .up, fast: true, slow: false))
        XCTAssertEqual(slow, InputState(dir: .up, fast: false, slow: true))
    }

    func testTheScriptRunsWithoutLosingALife() {
        var demo = Demo()

        let deaths = runToEnd(&demo)

        XCTAssertEqual(deaths, 0)
        XCTAssertFalse(demo.game.isOver)
    }

    func testTheDemoFinishesExactlyAfterTheTicksOfItsScript() {
        var demo = Demo()
        let total = scriptTicks(Demo.demoScript)

        for _ in 1 ..< total {
            demo.tick()
            XCTAssertFalse(demo.isFinished, "finished at tick \(demo.game.ticks)")
        }
        demo.tick()

        XCTAssertTrue(demo.isFinished)
        XCTAssertEqual(demo.game.ticks, total)
    }

    func testTheScriptClaimsFastAndSlowCellsBelowTheThreshold() {
        var demo = Demo()

        runToEnd(&demo)

        let game = demo.game
        XCTAssertGreaterThan(claimed(game, .fast), 0)
        XCTAssertGreaterThan(claimed(game, .slow), 0)
        XCTAssertFalse(game.isLevelComplete)
        let fraction = game.board.claimedFraction()
        XCTAssertFalse(game.claimThreshold.isReached(fraction), "claimed \(fraction)")
        XCTAssertTrue(demoClaimed.contains(fraction), "claimed \(fraction)")
    }

    func testTheScriptEndsWithNoStixHalfDrawn() {
        var demo = Demo()

        runToEnd(&demo)

        XCTAssertNil(demo.game.stix)
    }

    func testTheScriptLastsTwentyToThirtySeconds() {
        let seconds = Float(scriptTicks(Demo.demoScript)) / Float(Tuning.tickHz)

        XCTAssertTrue(demoSeconds.contains(seconds), "\(seconds) s")
    }

    func testTheScriptDrawsSlowStixAtTheSlowStepRate() {
        let slowTicks = Demo.demoScript.filter(\.input.slow).reduce(0) { $0 + $1.ticks }

        XCTAssertEqual(slowTicks, slowSteps * Tuning.slowStepTicks)
    }

    func testTwoDemosPlayTheSameGame() {
        var (first, second) = (Demo(), Demo())

        runToEnd(&first)
        runToEnd(&second)

        XCTAssertEqual(first.game.board, second.game.board)
        XCTAssertEqual(first.game.score, second.game.score)
    }

    func testAFinishedDemoDoesNotTick() {
        var demo = Demo(game: shortGame(), script: shortScript)
        runToEnd(&demo)
        let ticks = demo.game.ticks

        demo.tick()

        XCTAssertTrue(demo.isFinished)
        XCTAssertEqual(demo.game.ticks, ticks)
    }

    func testADemoTicksOneStepOfItsScriptPerTick() {
        var demo = Demo(game: shortGame(), script: shortScript)

        demo.tick()

        XCTAssertEqual(demo.game.ticks, 1)
        XCTAssertFalse(demo.isFinished)
    }

    func testAScriptThatRunsOutFinishesTheDemo() {
        var demo = Demo(game: sparxFreeGame(), script: idleScript)

        runToEnd(&demo)

        XCTAssertEqual(demo.game.ticks, UInt64(idleTicks))
        XCTAssertFalse(demo.game.isOver)
        XCTAssertFalse(demo.game.isLevelComplete)
    }

    func testAnEmptyScriptIsFinished() {
        let demo = Demo(game: sparxFreeGame(), script: [])

        XCTAssertTrue(demo.isFinished)
    }

    func testStepsOfNoTicksAreSkipped() {
        var demo = Demo(game: sparxFreeGame(), script: emptyStepScript)

        runToEnd(&demo)

        XCTAssertEqual(demo.game.ticks, UInt64(idleTicks))
    }

    func testADemoWhoseGameIsOverIsFinished() {
        var demo = Demo(game: sparxGame(), script: longIdleScript)

        let deaths = runToEnd(&demo)

        XCTAssertTrue(demo.game.isOver)
        XCTAssertTrue(demo.isFinished)
        XCTAssertEqual(deaths, Int(Tuning.startingLives))
        XCTAssertLessThan(demo.game.ticks, scriptTicks(longIdleScript))
    }

    func testADemoWhoseLevelIsCompleteIsFinishedBeforeItsScriptEnds() {
        var demo = Demo(game: shortGame(), script: shortScript)

        runToEnd(&demo)

        XCTAssertTrue(demo.game.isLevelComplete)
        XCTAssertTrue(demo.isFinished)
        XCTAssertEqual(demo.game.ticks, UInt64(shortStixSteps * Tuning.markerStepTicks))
    }

    func testTheDefaultDemoIsTheNewOne() {
        // Rust's `Demo::default()` and `Demo::new()` are both `Demo()` in Swift: it plays
        // `Demo.demoScript` on a game seeded with `Tuning.demoSeed`.
        var demo = Demo()
        runToEnd(&demo)

        var new = Demo(game: Game(rng: Rng(seed: Tuning.demoSeed)), script: Demo.demoScript)
        runToEnd(&new)
        XCTAssertEqual(demo.game.board, new.game.board)
    }
}
