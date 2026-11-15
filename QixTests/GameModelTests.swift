import QixKit
import XCTest
@testable import Qix

/// One frame at the tick rate: one tick.
private let frame: TimeInterval = 1.0 / Double(Tuning.tickHz)

/// Seed of every game the tests play.
private let modelSeed: UInt64 = 1

/// A stick pushed fully left.
private let stickLeft = PadState(x: -1)

/// A stand-in for a `UITouch`: only its identity counts.
private final class Finger: Sendable {}

private let thumbFinger = Finger()
private let slowFinger = Finger()
/// The touches of the tests: the left thumb on the stick, the right one on the Slow button.
private let thumb = ObjectIdentifier(thumbFinger)
private let slowThumb = ObjectIdentifier(slowFinger)

/// Where the stick's thumb lands, and the Slow button's, in the playfield's coordinates.
private let stickCentre = CGPoint(x: 60, y: 200)
private let slowPoint = CGPoint(x: 800, y: 200)

/// A drag on the stick well past its dead zone, in points.
private let drag = CGFloat(3 * FloatingStick.deadZone)

/// A game on a 4 x 2 board with a still Qix in its bottom-right cell and no Sparx: a fast stix up
/// one step and left two from the marker's start claims the bottom row's left half.
private func smallGame() -> Game {
    let qix = QixKit.Qix(a: Vec2(x: 3.25, y: 1.5), b: Vec2(x: 3.75, y: 1.5), vel: Vec2(), spin: 0)
    return Game(board: Board(width: 4, height: 2), qix: [qix], sparx: [], rng: Rng(seed: modelSeed))
}

@MainActor
final class GameModelTests: XCTestCase {
    private var model: GameModel!

    override func setUp() async throws {
        try await super.setUp()
        model = GameModel(session: Session(game: Game(rng: Rng(seed: modelSeed))))
    }

    /// Runs `count` frames of one tick each, the game pad as `pad`.
    private func frames(_ count: UInt32, pad: PadState? = nil) {
        for _ in 0 ..< count {
            model.advance(by: frame, pad: pad)
        }
    }

    /// Taps and runs the frame that starts the game.
    private func start(file: StaticString = #filePath, line: UInt = #line) {
        model.tap()
        frames(1)
        XCTAssertEqual(model.session.state, .playing, file: file, line: line)
    }

    func testANewModelShowsTheTitleScreenWithoutPauseButtonAndLetsTheScreenSleep() {
        XCTAssertEqual(model.session.state, .title)
        XCTAssertEqual(model.scene.screen, .title(HighScores()))
        XCTAssertNil(model.scene.pauseButton)
        XCTAssertFalse(model.keepsScreenAwake)
    }

    func testATapStartsTheGameOnTheNextFrame() {
        model.tap()
        XCTAssertEqual(model.session.state, .title)

        frames(1)

        XCTAssertEqual(model.session.state, .playing)
        XCTAssertNil(model.scene.screen)
        XCTAssertEqual(model.scene.pauseButton, .pause)
        XCTAssertTrue(model.keepsScreenAwake)
    }

    func testThePauseButtonPausesThenResumes() {
        start()

        model.pressPause()
        frames(1)
        XCTAssertEqual(model.session.state, .paused)
        XCTAssertEqual(model.scene.screen, .paused)
        XCTAssertEqual(model.scene.pauseButton, .resume)
        XCTAssertFalse(model.keepsScreenAwake)

        model.pressPause()
        frames(1)
        XCTAssertEqual(model.session.state, .playing)
    }

    func testAHeldKeyMovesTheMarkerUntilItsRelease() {
        start()
        let start = model.session.game.marker.pos

        model.keyDown(.left)
        frames(Tuning.markerStepTicks)
        let moved = Point(x: start.x - 1, y: start.y)
        XCTAssertEqual(model.session.game.marker.pos, moved)

        model.keyUp(.left)
        frames(2 * Tuning.markerStepTicks)
        XCTAssertEqual(model.session.game.marker.pos, moved)
    }

    func testReleasingEveryKeyStopsTheMarker() {
        start()
        let start = model.session.game.marker.pos
        model.keyDown(.left)

        model.releaseKeys()
        frames(2 * Tuning.markerStepTicks)

        XCTAssertEqual(model.session.game.marker.pos, start)
    }

    func testThePadStartsTheGameAndMovesTheMarkerWhileConnected() {
        frames(1, pad: PadState(south: true))
        XCTAssertEqual(model.session.state, .playing)
        let start = model.session.game.marker.pos

        frames(Tuning.markerStepTicks, pad: stickLeft)
        let moved = Point(x: start.x - 1, y: start.y)
        XCTAssertEqual(model.session.game.marker.pos, moved)

        frames(2 * Tuning.markerStepTicks, pad: nil)
        XCTAssertEqual(model.session.game.marker.pos, moved)
    }

    /// Lands the thumb on the stick and drags it `dx`, `dy` points.
    private func steer(_ dx: CGFloat, _ dy: CGFloat) {
        model.touch(.began(thumb, .stick, stickCentre))
        model.touch(.moved(thumb, CGPoint(x: stickCentre.x + dx, y: stickCentre.y + dy)))
    }

    func testADragOnTheStickMovesTheMarkerUntilTheThumbLifts() {
        start()
        let start = model.session.game.marker.pos

        steer(-drag, 0)
        frames(Tuning.markerStepTicks)
        let moved = Point(x: start.x - 1, y: start.y)
        XCTAssertEqual(model.session.game.marker.pos, moved)

        model.touch(.ended(thumb))
        frames(2 * Tuning.markerStepTicks)
        XCTAssertEqual(model.session.game.marker.pos, moved)
    }

    func testSteeringOffTheBorderDrawsAFastStixWithNoButton() {
        start()

        steer(0, -drag)
        frames(Tuning.markerStepTicks)

        XCTAssertEqual(model.session.game.stix?.kinds, [DrawKind.fast])
    }

    func testTheSlowButtonHeldDrawsASlowStix() {
        start()

        model.touch(.began(slowThumb, .slow, slowPoint))
        steer(0, -drag)
        frames(Tuning.slowStepTicks)

        XCTAssertEqual(model.session.game.stix?.kinds, [DrawKind.slow])
    }

    func testTheSceneShowsTheTouchControls() {
        steer(-drag, 0)
        model.touch(.began(slowThumb, .slow, slowPoint))

        let scene = model.scene

        XCTAssertEqual(scene.stick.centre, Vec2(stickCentre))
        XCTAssertEqual(scene.stick.dir, .left)
        XCTAssertTrue(scene.slowHeld)
    }

    func testSuspendingReleasesTheTouches() {
        start()
        steer(-drag, 0)
        model.touch(.began(slowThumb, .slow, slowPoint))

        model.suspend()

        XCTAssertEqual(model.touches, TouchControls())
        XCTAssertEqual(model.loop.controls.held, [])
    }

    /// A new game's marker is at the centre of the board's bottom edge.
    func testThePlayfieldReadsTheMarkersPosition() {
        XCTAssertEqual(model.scene.markerValue, "Marker at 80, 120")
    }

    func testSuspendingPausesTheGameAtOnce() {
        start()
        let ticks = model.session.game.ticks

        model.suspend()

        XCTAssertEqual(model.session.state, .paused)
        XCTAssertEqual(model.session.game.ticks, ticks)
    }

    func testTheSceneShowsTheSessionsGameAndHud() {
        start()
        frames(1)

        let scene = model.scene

        XCTAssertEqual(scene.game, model.session.game)
        XCTAssertEqual(scene.hud, Hud(game: model.session.game, highScore: model.session.highScore))
    }

    func testTheBoardIsRedrawnOnlyWhenItChanges() throws {
        model = GameModel(session: Session(game: smallGame()))
        start()
        let first = try XCTUnwrap(model.board.claimed)

        model.keyDown(.fast)
        model.keyDown(.up)
        frames(Tuning.markerStepTicks)
        XCTAssertNotNil(model.session.game.stix)
        XCTAssertTrue(try XCTUnwrap(model.board.claimed) === first, "redrawn without a claim")

        model.keyUp(.up)
        model.keyDown(.left)
        frames(2 * Tuning.markerStepTicks)
        XCTAssertNil(model.session.game.stix)
        XCTAssertEqual(model.session.game.board.claimedFraction(), 0.25)
        XCTAssertFalse(try XCTUnwrap(model.board.claimed) === first, "not redrawn after the claim")
        XCTAssertEqual(model.board.board, model.session.game.board)
    }

    func testAGameIsSeededWithTheNanosecondsSinceTheEpoch() {
        XCTAssertEqual(GameModel.seed(at: Date(timeIntervalSince1970: 1.5)), 1_500_000_000)
    }

    func testAClockOutOfRangeSeedsZero() {
        XCTAssertEqual(GameModel.seed(at: Date(timeIntervalSince1970: -1)), 0)
        XCTAssertEqual(GameModel.seed(at: .distantFuture), 0)
    }
}
