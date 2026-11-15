// `Session.events`: the events of the game tick a session tick ran, and none from a tick that did
// not tick the game.

import XCTest
@testable import QixKit

final class StateEventsTests: XCTestCase {
    func testANewSessionHasNoEvents() {
        XCTAssertEqual(Session(game: levelGame()).events, [])
    }

    func testAPlayingTickReportsTheEventsOfTheGame() {
        var session = playing(levelGame())

        for _ in 0 ..< Tuning.markerStepTicks {
            session.tick(drawUpInput)
            XCTAssertEqual(session.events, session.game.events)
        }
        XCTAssertEqual(session.events, [.draw(.fast)])
    }

    func testTheTickThatPausesReportsNoEvents() {
        var session = playing(levelGame())
        hold(&session, drawUpInput, Tuning.markerStepTicks)
        XCTAssertFalse(session.events.isEmpty, "the stix did not step")

        session.tick(pauseInput)

        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.events, [])
        XCTAssertFalse(session.game.events.isEmpty)
    }

    func testTheTicksAfterACompletedLevelReportNoEvents() {
        var session = completedLevel()
        guard case .levelComplete = session.events.last else {
            return XCTFail("\(session.events)")
        }

        session.tick(InputState())

        XCTAssertTrue(isLevelComplete(session.state), "\(session.state)")
        XCTAssertEqual(session.events, [])
    }

    func testTheConfirmThatStartsTheNextLevelReportsNoEvents() {
        var session = completedLevel()

        session.tick(confirmInput)

        XCTAssertEqual(session.state, .playing)
        XCTAssertEqual(session.events, [])
    }
}
