import CoreGraphics
import XCTest
@testable import Qix

/// The safe area of `PlayfieldLayoutTests`' phone, whose board is 320 × 240 at x 148 and y 32.
private let phone = CGRect(x: 0, y: 0, width: 616, height: 280)

/// Where the stick's thumb lands in the knob tests.
private let centre = CGPoint(x: 100, y: 100)

/// Tolerance for comparing screen coordinates, in points.
private let epsilon: CGFloat = 1e-9

final class ControlsLayoutTests: XCTestCase {
    /// 16 points from the safe area's edges and 8 from the board: 148 - 8 - 16 = 124 points wide,
    /// 280 - 2 × 16 = 248 high.
    func testTheZonesFlankTheBoardClearOfTheEdges() {
        let layout = ControlsLayout(in: phone, beside: PlayfieldLayout(in: phone).field)

        XCTAssertEqual(layout.stick, CGRect(x: 16, y: 16, width: 124, height: 248))
        XCTAssertEqual(layout.slow, CGRect(x: 476, y: 16, width: 124, height: 248))
        XCTAssertEqual(layout.stickRest, CGPoint(x: 78, y: 140))
        XCTAssertEqual(layout.slowCentre, CGPoint(x: 538, y: 140))
    }

    func testTheZonesFollowAnOffsetSafeArea() {
        let available = phone.offsetBy(dx: 50, dy: 20)

        let layout = ControlsLayout(in: available, beside: PlayfieldLayout(in: available).field)

        XCTAssertEqual(layout.stick, CGRect(x: 66, y: 36, width: 124, height: 248))
        XCTAssertEqual(layout.slow, CGRect(x: 526, y: 36, width: 124, height: 248))
    }

    func testABoardLeavingNoRoomGivesEmptyZones() {
        let available = CGRect(x: 0, y: 0, width: 100, height: 100)

        let layout = ControlsLayout(in: available, beside: CGRect(x: 20, y: 0, width: 60, height: 100))

        XCTAssertTrue(layout.stick.isEmpty)
        XCTAssertTrue(layout.slow.isEmpty)
    }

    func testASafeAreaShorterThanItsClearancesGivesEmptyZones() {
        let available = CGRect(x: 0, y: 0, width: 616, height: ControlsLayout.edgeClearance)

        let layout = ControlsLayout(in: available, beside: CGRect(x: 300, y: 0, width: 16, height: 16))

        XCTAssertEqual(layout.stick.height, 0)
        XCTAssertEqual(layout.slow.height, 0)
    }

    func testTheKnobIsUnderAThumbOnTheBase() {
        let thumb = CGPoint(x: 110, y: 120)

        XCTAssertEqual(ControlsLayout.knob(centre: centre, thumb: thumb), thumb)
    }

    func testTheKnobIsUnderAThumbOnTheRim() {
        let thumb = CGPoint(x: centre.x, y: centre.y - ControlsLayout.baseRadius)

        XCTAssertEqual(ControlsLayout.knob(centre: centre, thumb: thumb), thumb)
    }

    /// A thumb 100 points away along a 3-4-5 triangle: the knob is 44 points away along it.
    func testTheKnobStaysOnTheRimTowardsAThumbBeyondIt() {
        let knob = ControlsLayout.knob(centre: centre, thumb: CGPoint(x: 160, y: 180))

        XCTAssertEqual(knob.x, 100 + 0.6 * ControlsLayout.baseRadius, accuracy: epsilon)
        XCTAssertEqual(knob.y, 100 + 0.8 * ControlsLayout.baseRadius, accuracy: epsilon)
    }
}
