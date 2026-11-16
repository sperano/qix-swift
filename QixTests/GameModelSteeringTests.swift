import Foundation
import QixKit
import XCTest
@testable import Qix

/// One frame at the tick rate: one tick.
private let frame: TimeInterval = 1.0 / Double(Tuning.tickHz)

/// The board on a screen of one point a cell, its top-left corner at the screen's.
private let board = BoardFrame(origin: Vec2(), pointsPerCell: 1)

/// The lattice point the finger aims at, above the marker's start at `(80, 120)`, and where the
/// finger is for it.
private let target = Point(x: 80, y: 100)
private let fingerPoint = CGPoint(x: 80, y: 100 + CGFloat(BoardFrame.fingerLift))

/// A stand-in for a `UITouch`: only its identity counts.
private final class Finger: Sendable {}

private let finger = Finger()

/// Follow the finger in the model: a finger on the board steers in play, taps out of it, and the
/// cursor shows its target.
@MainActor
final class GameModelSteeringTests: XCTestCase {
    private var model: GameModel!

    override func setUp() async throws {
        try await super.setUp()
        let game = Game(rng: Rng(seed: 0))
        model = GameModel(session: Session(game: game), settings: Settings(controlScheme: .followTheFinger))
    }

    private func frames(_ count: UInt32) {
        for _ in 0 ..< count {
            model.advance(by: frame, pad: nil)
        }
    }

    private func touchTheBoard() {
        model.touch(.began(touch: ObjectIdentifier(finger), on: .board(board), at: fingerPoint))
    }

    private func lift() {
        model.touch(.ended(touch: ObjectIdentifier(finger)))
    }

    private func start(file: StaticString = #filePath, line: UInt = #line) {
        model.tap()
        frames(1)
        XCTAssertEqual(model.session.state, .playing, file: file, line: line)
    }

    func testAFingerOnTheBoardInPlaySteersTheMarkerAndShowsTheCursor() {
        start()

        touchTheBoard()
        frames(Tuning.markerStepTicks)

        XCTAssertEqual(model.session.game.marker.pos, Point(x: 80, y: 119))
        XCTAssertEqual(model.session.game.stix?.kinds, [.fast])
        XCTAssertEqual(model.scene.cursor, target)
    }

    func testLiftingTheFingerLetsGoOfTheTarget() {
        start()
        touchTheBoard()

        lift()

        XCTAssertEqual(model.loop.steering, TouchSteering())
        XCTAssertNil(model.scene.cursor)
        XCTAssertEqual(model.session.state, .playing)
    }

    func testAFingerOnTheBoardOutOfPlayStartsTheGameOnceLifted() {
        touchTheBoard()
        frames(1)
        XCTAssertEqual(model.session.state, .title)
        XCTAssertNil(model.loop.steering.aim)

        lift()
        frames(1)

        XCTAssertEqual(model.session.state, .playing)
        XCTAssertEqual(model.touches, TouchControls())
    }

    func testAFingerOnTheBoardOnHoldIsNoTap() {
        model.openSettings()
        touchTheBoard()
        lift()
        model.isShowingSettings = false

        frames(1)

        XCTAssertEqual(model.session.state, .title)
    }

    /// Paused, the finger still aims, but no cursor shows.
    func testTheCursorShowsInPlayOnly() {
        start()
        touchTheBoard()

        model.pressPause()
        frames(1)

        XCTAssertEqual(model.session.state, .paused)
        XCTAssertEqual(model.loop.steering.target(on: model.session.game.board), target)
        XCTAssertNil(model.scene.cursor)
    }
}
