import XCTest
@testable import QixKit

/// The column of the full board the Qix is `pen`ned in, left of the stix the tests draw up from the
/// marker's start.
private let penColumn: UInt16 = 1

/// Steps of the first segment of the stix
/// `testTheClosingStepRaisesItsDrawThenTheClaimThenItsExtraLives` draws, in the cases that draw
/// one, before the segment that closes it.
private let firstSegmentSteps: UInt32 = 3

/// A full-size game with no Sparx and its Qix penned in `penColumn`.
private func pennedGame() -> Game {
    var board = Board(width: Tuning.boardW, height: Tuning.boardH)
    let qix = pen(&board, penColumn)
    return Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed))
}

/// Ticks `game` with `kind` held up for `ticks` ticks and returns every event raised, in order.
private func eventsDrawingUp(_ game: inout Game, _ kind: DrawKind, _ ticks: UInt32) -> [Event] {
    var events: [Event] = []
    for _ in 0 ..< ticks {
        game.tick(drawing(.up, kind))
        events.append(contentsOf: game.events)
    }
    return events
}

/// Draws the stix up from where the marker is with `kind` until it closes, and returns the events of
/// the closing tick.
private func closeUp(_ game: inout Game, _ kind: DrawKind) -> [Event] {
    let input = drawing(.up, kind)
    var drawn = game.stix != nil
    for _ in 0 ..< UInt32(Tuning.boardH) * drawStepTicks(kind) {
        game.tick(input)
        if drawn, game.stix == nil {
            return game.events
        }
        drawn = drawn || game.stix != nil
    }
    XCTFail("the stix did not close")
    return []
}

/// The cells claimed on `game`'s board since it had `before` of it.
private func cellsClaimedSince(_ game: Game, _ before: Float) -> Int {
    let total = Float(Tuning.boardW) * Float(Tuning.boardH)
    return Int(((game.board.claimedFraction() - before) * total).rounded())
}

/// The `Event.draw` and `Event.claim` a stix raises through `Game.tick`, which the application plays
/// sounds for.
final class GameEventsTests: XCTestCase {
    func testEachStepOfTheStixRaisesADrawOfItsKind() {
        for kind in [DrawKind.fast, .slow] {
            var game = pennedGame()
            let steps: UInt32 = 3

            let events = eventsDrawingUp(&game, kind, steps * drawStepTicks(kind))

            XCTAssertEqual(events, Array(repeating: Event.draw(kind), count: Int(steps)), "\(kind)")
        }
    }

    func testOnlyTheTickOfAStepRaisesItsDraw() {
        var game = pennedGame()
        let input = drawing(.up, .slow)

        hold(&game, input, drawStepTicks(.slow) - 1)
        XCTAssertEqual(game.events, [])
        game.tick(input)
        XCTAssertEqual(game.events, [.draw(.slow)])
    }

    func testWalkingTheBorderRaisesNoDraw() {
        var game = pennedGame()

        for _ in 0 ..< Tuning.markerStepTicks * 3 {
            game.tick(holding(.right))
            XCTAssertEqual(game.events, [])
        }
    }

    func testTheClosingStepRaisesItsDrawThenTheClaimThenItsExtraLives() {
        let cases: [(DrawKind?, DrawKind, DrawKind)] = [
            (nil, .fast, .fast),
            (.slow, .slow, .slow),
            (.slow, .fast, .fast),
            (.fast, .slow, .fast),
        ]
        for (first, last, claimKind) in cases {
            var game = pennedGame()
            let before = game.board.claimedFraction()
            if let kind = first {
                draw(&game, .up, kind, firstSegmentSteps)
            }

            let events = closeUp(&game, last)

            let lives = game.lives - Tuning.startingLives
            let label = "\(String(describing: first)) then \(last)"
            XCTAssert(lives > 0, "\(label): no extra life")
            var expected: [Event] = [
                .draw(last),
                .claim(cells: cellsClaimedSince(game, before), kind: claimKind),
            ]
            expected.append(contentsOf: Array(repeating: Event.extraLife, count: Int(lives)))
            XCTAssertEqual(events, expected, label)
        }
    }
}
