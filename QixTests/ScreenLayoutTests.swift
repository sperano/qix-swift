import CoreGraphics
import QixKit
import XCTest
@testable import Qix

/// The board's height on the iPhone 17 in landscape, in points.
private let fieldHeight: CGFloat = 300

/// Tolerance for comparing sizes, in points.
private let epsilon: CGFloat = 1e-9

/// A table as long as the high score table gets.
private let fullTable = Array(repeating: "10. ABC  123,456", count: Tuning.highScoreCount)

final class ScreenLayoutTests: XCTestCase {
    func testThePanelHoldsTheHeadingTheRowsTheGapsAndThePadding() {
        let screen = Screen(heading: "H", table: ["row"], lines: ["one", "two"])

        let heading = ScreenLayout.headingScale * ScreenLayout.rowHeight
        let rows = 3 * ScreenLayout.rowHeight
        let expected = heading + 2 * ScreenLayout.gap + rows + 2 * ScreenLayout.padding
        XCTAssertEqual(ScreenLayout.panelHeight(screen), expected, accuracy: epsilon)
    }

    func testAScreenWithoutATableHasNoGapUnderIt() {
        let screen = Screen(heading: "H", lines: ["one"])

        let expected = ScreenLayout.headingScale * ScreenLayout.rowHeight + ScreenLayout.gap
            + ScreenLayout.rowHeight + 2 * ScreenLayout.padding
        XCTAssertEqual(ScreenLayout.panelHeight(screen), expected, accuracy: epsilon)
    }

    func testAShortScreenTakesTheLargestLines() {
        XCTAssertEqual(ScreenLayout.lineSize(.paused, fieldHeight: fieldHeight), ScreenLayout.lineShare * fieldHeight)
    }

    func testATallScreenShrinksToFitTheBoard() {
        let title = Screen(heading: "QIX", table: fullTable, lines: Screen.title(HighScores()).lines)

        let line = ScreenLayout.lineSize(title, fieldHeight: fieldHeight)

        XCTAssertLessThan(line, ScreenLayout.lineShare * fieldHeight)
        XCTAssertEqual(
            line * ScreenLayout.panelHeight(title),
            ScreenLayout.maxPanelShare * fieldHeight,
            accuracy: epsilon
        )
    }
}
