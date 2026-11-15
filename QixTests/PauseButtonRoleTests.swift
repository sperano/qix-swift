import QixKit
import XCTest
@testable import Qix

final class PauseButtonRoleTests: XCTestCase {
    func testTheButtonPausesPlayAndResumesThePause() {
        XCTAssertEqual(PauseButtonRole(.playing), .pause)
        XCTAssertEqual(PauseButtonRole(.paused), .resume)
    }

    func testThereIsNoButtonOutOfPlay() {
        let states: [GameState] = [
            .title, .levelComplete(fraction: 0.8, bonus: 5_000, split: false), .gameOver,
            .highScoreEntry(InitialsEntry()),
        ]
        for state in states {
            XCTAssertNil(PauseButtonRole(state), "\(state)")
        }
    }

    func testEachRoleShowsItsSymbolAndReadsItsLabel() {
        XCTAssertEqual(PauseButtonRole.pause.symbol, "pause.fill")
        XCTAssertEqual(PauseButtonRole.pause.label, "Pause")
        XCTAssertEqual(PauseButtonRole.resume.symbol, "play.fill")
        XCTAssertEqual(PauseButtonRole.resume.label, "Resume")
    }
}
