import QixKit
import XCTest
@testable import Qix

final class HudButtonRoleTests: XCTestCase {
    func testTheButtonPausesPlayResumesThePauseAndOpensTheSettingsFromTheTitle() {
        XCTAssertEqual(HudButtonRole(.playing), .pause)
        XCTAssertEqual(HudButtonRole(.paused), .resume)
        XCTAssertEqual(HudButtonRole(.title), .settings)
    }

    func testThereIsNoButtonOnTheOtherScreens() {
        let states: [GameState] = [
            .levelComplete(fraction: 0.8, bonus: 5_000, split: false), .gameOver, .highScoreEntry(InitialsEntry()),
        ]
        for state in states {
            XCTAssertNil(HudButtonRole(state), "\(state)")
        }
    }

    func testEachRoleShowsItsSymbolAndReadsItsLabel() {
        XCTAssertEqual(HudButtonRole.pause.symbol, "pause.fill")
        XCTAssertEqual(HudButtonRole.pause.label, "Pause")
        XCTAssertEqual(HudButtonRole.resume.symbol, "play.fill")
        XCTAssertEqual(HudButtonRole.resume.label, "Resume")
        XCTAssertEqual(HudButtonRole.settings.symbol, "gearshape.fill")
        XCTAssertEqual(HudButtonRole.settings.label, "Settings")
    }

    func testPauseAndResumeShareAnIdentifierAndTheSettingsHaveTheirOwn() {
        XCTAssertEqual(HudButtonRole.pause.identifier, "pause")
        XCTAssertEqual(HudButtonRole.resume.identifier, "pause")
        XCTAssertEqual(HudButtonRole.settings.identifier, "settings")
    }
}
