import XCTest
@testable import QixKit

/// Dimensions of the board: the marker starts at `(width / 2, height)`, below a free column.
private let width: UInt16 = 8
private let height: UInt16 = 6

/// The column the Qix is penned in, clear of the stix the tests draw up from the marker.
private let penColumn: UInt16 = 1

/// Steps of the stix the fuse tests draw up from the border: one segment.
private let fuseStixSteps: UInt32 = 2

/// Ticks the fuse of a one-segment stix takes to light and burn to a marker standing still at its
/// head.
private let burnTicks = Tuning.fuseDelayTicks + Tuning.fuseStepTicks

/// A session in play over a game on a `width x height` board with the Qix penned in `penColumn`
/// and no Sparx.
private func pennedSession(file: StaticString = #filePath, line: UInt = #line) -> Session {
    let (board, qix) = penned(width, height, penColumn)
    return playing(Game(board: board, qix: [qix], sparx: [], rng: Rng(seed: gameSeed)), file: file, line: line)
}

/// The event is a claim.
private func isClaim(_ event: Event) -> Bool {
    if case .claim = event {
        return true
    }
    return false
}

/// `count` ticks raising no haptic.
private func none(_ count: UInt32) -> [Haptic?] {
    Array(repeating: nil, count: Int(count))
}

final class HapticTests: XCTestCase {
    private var session = Session(game: newGame())
    private var cues = HapticCues()

    override func setUp() {
        super.setUp()
        session = pennedSession()
        cues = HapticCues()
    }

    /// Ticks the session `ticks` times with `input` and returns the haptic the cues raise at each
    /// tick.
    private func feel(_ input: InputState, _ ticks: UInt32 = 1) -> [Haptic?] {
        (0 ..< ticks).map { _ in
            let marker = session.game.marker
            session.tick(input)
            return cues.cue(input, from: marker, to: session)
        }
    }

    func testPressingADirectionTicksOnceForTheWholeHold() {
        let ticks = 3 * Tuning.markerStepTicks

        XCTAssertEqual(feel(drawing(.left, .fast), ticks), [.tick] + none(ticks - 1))
        XCTAssertNotEqual(session.game.marker.pos, Marker.start(session.game.board).pos)
    }

    func testChangingDirectionTicks() {
        _ = feel(drawing(.left, .fast), Tuning.markerStepTicks)

        XCTAssertEqual(feel(drawing(.right, .fast)), [.tick])
    }

    func testLettingGoFeelsNothingAndTheNextPressTicksAgain() {
        _ = feel(drawing(.left, .fast), Tuning.markerStepTicks)

        XCTAssertEqual(feel(InputState(), Tuning.markerStepTicks), none(Tuning.markerStepTicks))
        XCTAssertEqual(feel(drawing(.left, .fast)), [.tick])
    }

    /// The first tick ticks for the press, the second, the stix's first step, for leaving the
    /// border.
    func testLeavingTheBorderTicks() {
        let ticks = 2 * Tuning.markerStepTicks

        XCTAssertEqual(feel(drawing(.up, .fast), ticks), [.tick, .tick] + none(ticks - 2))
        XCTAssertEqual(session.game.marker.state, .drawing)
    }

    /// Off the bottom edge, the step is refused every `Tuning.markerStepTicks`: the first refusal
    /// bumps, the next ones of the same hold do not.
    func testARefusedStepBumpsOncePerHold() {
        let ticks = 4 * Tuning.markerStepTicks
        let start = session.game.marker.pos

        XCTAssertEqual(feel(drawing(.down, .fast), ticks), [.tick, .bump] + none(ticks - 2))
        XCTAssertEqual(session.game.marker.pos, start)

        XCTAssertEqual(feel(InputState()), [nil])
        XCTAssertEqual(feel(drawing(.down, .fast), Tuning.markerStepTicks), [.tick, .bump])
    }

    /// With no draw button, the core does not step the marker off the border.
    func testADirectionIntoTheBoardWithNoDrawButtonBumps() {
        XCTAssertEqual(feel(holding(.up), Tuning.markerStepTicks), [.tick, .bump])
        XCTAssertEqual(session.game.marker.state, .onBorder)
    }

    func testTurningOntoARefusedStepTicksThenBumps() {
        _ = feel(drawing(.left, .fast), Tuning.markerStepTicks)

        XCTAssertEqual(feel(drawing(.down, .fast), Tuning.markerStepTicks), [.tick, .bump])
    }

    /// Standing still on the stix with a direction and no draw button is no refusal: the core
    /// stops the marker until a draw button is held.
    func testStandingOnTheStixWithADirectionHeldDoesNotBump() {
        _ = feel(drawing(.up, .fast), fuseStixSteps * Tuning.markerStepTicks)
        let ticks = 2 * Tuning.markerStepTicks

        XCTAssertEqual(feel(holding(.up), ticks), none(ticks))
        XCTAssertNotNil(session.game.stix)
    }

    func testAClaimSucceeds() {
        let ticks = UInt32(height) * Tuning.markerStepTicks

        let haptics = feel(drawing(.up, .fast), ticks)

        XCTAssertEqual(haptics.last, .success)
        XCTAssertTrue(session.events.contains(where: isClaim))
        XCTAssertNil(session.game.stix)
    }

    /// The tick before the claim turns, so the turn's step count closes the stix on the next one:
    /// the claim wins over the turn.
    func testAClaimOnATurnSucceeds() {
        _ = feel(drawing(.up, .fast), UInt32(height - 1) * Tuning.markerStepTicks)

        XCTAssertEqual(feel(drawing(.right, .fast)), [.tick])
        XCTAssertEqual(feel(drawing(.up, .fast)), [.success])
    }

    /// The fuse kills the marker standing at the head of its stix; on the deadly tick a direction
    /// is pressed, and the death wins over the turn.
    func testADeathErrsOverATurn() {
        _ = feel(drawing(.up, .fast), fuseStixSteps * Tuning.markerStepTicks)

        XCTAssertEqual(feel(InputState(), burnTicks - 1), none(burnTicks - 1))
        XCTAssertEqual(feel(holding(.left)), [.error])
        XCTAssertEqual(session.events, [.death(.fuse)])
    }

    /// A tick that does not tick the game feels nothing and forgets the direction: holding it on
    /// after the pause ticks again.
    func testATickOutOfPlayFeelsNothingAndForgetsTheDirection() {
        let left = drawing(.left, .fast)
        var pausing = left
        pausing.pause = true
        _ = feel(left)

        XCTAssertEqual(feel(pausing), [nil])
        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(feel(left, Tuning.markerStepTicks), none(Tuning.markerStepTicks))
        XCTAssertEqual(feel(pausing), [nil])
        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(feel(left), [.tick])
    }
}
