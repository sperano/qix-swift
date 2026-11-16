import CoreGraphics
import QixKit
import XCTest
@testable import Qix

/// The board's width over its height, 160 by 120 cells.
private let fourByThree: CGFloat = 4.0 / 3.0

/// An area whose 264 points of height inside the margins fit the 132 units of the board and the HUD
/// twice over, and whose width leaves room on both sides.
private let phone = CGRect(x: 0, y: 0, width: 616, height: 280)

/// Tolerance for comparing screen coordinates, in points.
private let epsilon: CGFloat = 1e-9

final class PlayfieldLayoutTests: XCTestCase {
    /// A landscape phone: the 600 × 300 inside the margins is wider than 4:3, so the height binds
    /// and the rectangle is 400 × 300 with 100 points on each side.
    func testAWideAreaLetterboxesTheSides() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 616, height: 316), aspectRatio: fourByThree)
        XCTAssertEqual(field, CGRect(x: 108, y: 8, width: 400, height: 300))
    }

    /// 384 × 300 inside the margins is narrower than 4:3, so the width binds: 384 × 288, 6 points
    /// above and below.
    func testANarrowAreaLetterboxesTopAndBottom() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 400, height: 316), aspectRatio: fourByThree)
        XCTAssertEqual(field, CGRect(x: 8, y: 14, width: 384, height: 288))
    }

    func testTheRectangleIsCentredInAnOffsetArea() {
        let field = PlayfieldLayout.letterbox(
            in: CGRect(x: 50, y: 20, width: 616, height: 316),
            aspectRatio: fourByThree
        )
        XCTAssertEqual(field, CGRect(x: 158, y: 28, width: 400, height: 300))
    }

    func testAnotherAspectRatioIsKept() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 316, height: 316), aspectRatio: 2)
        XCTAssertEqual(field, CGRect(x: 8, y: 83, width: 300, height: 150))
    }

    func testAnAreaNoWiderThanItsMarginsGivesAnEmptyRectangleAtItsCentre() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 16, height: 100))
        XCTAssertEqual(field, CGRect(x: 8, y: 50, width: 0, height: 0))
    }

    func testAnAreaSmallerThanItsMarginsGivesAnEmptyRectangleAtItsCentre() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 10, height: 4))
        XCTAssertEqual(field, CGRect(x: 5, y: 2, width: 0, height: 0))
    }

    func testTheDefaultRatioIsTheBoardWithTheHudAbove() {
        XCTAssertEqual(PlayfieldLayout.aspectRatio, 160.0 / 132.0, accuracy: epsilon)
    }

    func testTheHudSitsRightAboveTheBoardAsWideAsIt() {
        let layout = PlayfieldLayout(in: phone)

        XCTAssertEqual(layout.hud, CGRect(x: 148, y: 8, width: 320, height: 24))
        XCTAssertEqual(layout.field, CGRect(x: 148, y: 32, width: 320, height: 240))
    }

    func testTheBoardKeepsItsShape() {
        let layout = PlayfieldLayout(in: CGRect(x: 0, y: 0, width: 874, height: 402))

        XCTAssertEqual(layout.field.width / layout.field.height, fourByThree, accuracy: epsilon)
    }

    func testLatticePointsAndVectorsMapThroughTheBoardsScale() {
        let layout = PlayfieldLayout(in: phone)

        XCTAssertEqual(layout.scale, 2)
        XCTAssertEqual(layout.position(Point(x: 10, y: 20)), CGPoint(x: 168, y: 72))
        XCTAssertEqual(layout.position(Vec2(x: 0.5, y: 1.5)), CGPoint(x: 149, y: 35))
        XCTAssertEqual(layout.position(Point(x: Tuning.boardW, y: Tuning.boardH)), CGPoint(x: 468, y: 272))
    }

    /// A finger `BoardFrame.fingerLift` below lattice point `(10, 20)` aims at it.
    func testTheBoardFrameIsTheBoardsCornerAndScale() {
        let layout = PlayfieldLayout(in: phone)

        XCTAssertEqual(layout.boardFrame, BoardFrame(origin: Vec2(x: 148, y: 32), pointsPerCell: 2))
        let finger = Vec2(layout.position(Point(x: 10, y: 20))) + Vec2(x: 0, y: BoardFrame.fingerLift)
        XCTAssertEqual(layout.boardFrame.aim(at: finger), Vec2(x: 10, y: 20))
    }

    /// Cells 10 to 12 of row 20 start at lattice point `(10, 20)` and are 3 by 1 cells.
    func testARunCoversItsCellsOnScreen() {
        let layout = PlayfieldLayout(in: phone)

        let rect = layout.rect(of: CellRun(row: 20, cols: 10 ..< 13, kind: .fast))

        XCTAssertEqual(rect, CGRect(x: 168, y: 72, width: 6, height: 2))
    }
}
