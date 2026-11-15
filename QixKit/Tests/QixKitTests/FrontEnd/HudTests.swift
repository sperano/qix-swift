import XCTest
@testable import QixKit

/// Seed of every game the tests play.
private let hudSeed: UInt64 = 1_207

/// Ticks of the meter the tests count down.
private let meterTicks: UInt32 = 4

/// The cells the stix of `scoredGame` claims: at `Tuning.maxMultiplier`, more than a thousand
/// points.
private let scoredCells: UInt16 = 14

/// A game on a `width x 1` board with its first `claimed` cells claimed.
private func claimedGame(_ width: UInt16, _ claimed: UInt16) -> Game {
    var board = Board(width: width, height: 1)
    for x in 0 ..< claimed {
        board.setCell(x: x, y: 0, to: .claimed(.fast))
    }
    return Game(board: board, qix: [qixAt((width - 1, 0))], sparx: [], rng: Rng(seed: hudSeed))
}

/// A game at `Tuning.maxMultiplier` on a `2 * scoredCells x 2` board with a still Qix in its
/// bottom-right cell, that drew a fast stix up and left from the marker's start, claiming the
/// `scoredCells` cells of the bottom row's left half.
private func scoredGame(file: StaticString = #filePath, line: UInt = #line) -> Game {
    let (width, height) = (2 * scoredCells, UInt16(2))
    var game = Game(
        board: Board(width: width, height: height), qix: [qixAt((width - 1, height - 1))], sparx: [],
        rng: Rng(seed: hudSeed)
    )
    game.setMultiplier(Tuning.maxMultiplier)
    for (dir, steps) in [(Dir.up, UInt32(1)), (.left, UInt32(scoredCells))] {
        for _ in 0 ..< steps * Tuning.markerStepTicks {
            game.tick(InputState(dir: dir, fast: true))
        }
    }
    XCTAssertNil(game.stix, "the stix did not close", file: file, line: line)
    return game
}

final class HudTests: XCTestCase {
    func testANewGameShowsNoPointsItsLivesLevelAndAFullMeter() {
        let hud = Hud(game: Game(rng: Rng(seed: hudSeed)), highScore: 0)

        XCTAssertEqual(
            hud,
            Hud(
                score: "0", highScore: "0", level: "1", lives: Tuning.startingLives, claimed: "0.0% / 75%",
                meter: Meter(fraction: 1, next: .release), multiplier: nil
            )
        )
    }

    func testTheHighScoreHasThousandsSeparators() {
        let hud = Hud(game: Game(rng: Rng(seed: hudSeed)), highScore: 1_234_567)

        XCTAssertEqual(hud.highScore, "1,234,567")
    }

    func testTheClaimedShareIsRoundedDownToATenth() {
        // Two thirds: 66.67% rounded, 66.6% down.
        XCTAssertEqual(Hud(game: claimedGame(3, 2), highScore: 0).claimed, "66.6% / 75%")
    }

    func testAClaimedShareOnATenthShowsThatTenth() {
        // 0.7 and 0.9 as `Float` lie a hair below the tenth.
        XCTAssertEqual(Hud(game: claimedGame(10, 7), highScore: 0).claimed, "70.0% / 75%")
        XCTAssertEqual(Hud(game: claimedGame(10, 9), highScore: 0).claimed, "90.0% / 75%")
    }

    func testTheScoreHasThousandsSeparators() {
        let game = scoredGame()

        XCTAssertEqual(game.score.points, 1_260)
        XCTAssertEqual(Hud(game: game, highScore: 0).score, "1,260")
    }

    func testTheClaimedShareIsShownAgainstTheGamesThreshold() {
        var game = claimedGame(4, 1)
        game.setClaimThreshold(ClaimThreshold(0.5))

        XCTAssertEqual(Hud(game: game, highScore: 0).claimed, "25.0% / 50%")
    }

    func testTheMultiplierShowsOnlyAboveOne() {
        var game = Game(rng: Rng(seed: hudSeed))
        XCTAssertNil(Hud(game: game, highScore: 0).multiplier)

        game.setMultiplier(3)

        XCTAssertEqual(Hud(game: game, highScore: 0).multiplier, "x3")
    }

    func testTheLevelAndTheLivesAreTheGames() {
        var game = Game(rng: Rng(seed: hudSeed))
        game.startLevel(4)

        let hud = Hud(game: game, highScore: 0)

        XCTAssertEqual(hud.level, "4")
        XCTAssertEqual(hud.lives, game.lives)
    }

    func testTheMeterShrinksTwiceThenIsSpent() {
        var meter = SparxMeter(length: meterTicks)
        meter.tick()
        let release = Meter(meter)
        for _ in 1 ..< meterTicks {
            meter.tick()
        }
        let superSparx = Meter(meter)
        for _ in 0 ..< meterTicks {
            meter.tick()
        }
        let spent = Meter(meter)

        XCTAssertEqual(release, Meter(fraction: 0.75, next: .release))
        XCTAssertEqual(superSparx, Meter(fraction: 1, next: .super))
        XCTAssertEqual(spent, Meter(fraction: 0, next: nil))
    }
}
