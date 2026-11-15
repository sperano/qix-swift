import CoreGraphics
import XCTest
@testable import Qix

final class PlayfieldLayoutTests: XCTestCase {
    /// A landscape phone: the 600 × 300 inside the margins is wider than 4:3, so the height binds
    /// and the playfield is 400 × 300 with 100 points on each side.
    func testAWideAreaLetterboxesTheSides() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 616, height: 316))
        XCTAssertEqual(field, CGRect(x: 108, y: 8, width: 400, height: 300))
    }

    /// 384 × 300 inside the margins is narrower than 4:3, so the width binds: 384 × 288, 6 points
    /// above and below.
    func testANarrowAreaLetterboxesTopAndBottom() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 400, height: 316))
        XCTAssertEqual(field, CGRect(x: 8, y: 14, width: 384, height: 288))
    }

    func testThePlayfieldIsCentredInAnOffsetArea() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 50, y: 20, width: 616, height: 316))
        XCTAssertEqual(field, CGRect(x: 158, y: 28, width: 400, height: 300))
    }

    func testAnotherAspectRatioIsKept() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 316, height: 316), aspectRatio: 2)
        XCTAssertEqual(field, CGRect(x: 8, y: 83, width: 300, height: 150))
    }

    func testAnAreaNoWiderThanItsMarginsGivesAnEmptyPlayfieldAtItsCentre() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 16, height: 100))
        XCTAssertEqual(field, CGRect(x: 8, y: 50, width: 0, height: 0))
    }

    func testAnAreaSmallerThanItsMarginsGivesAnEmptyPlayfieldAtItsCentre() {
        let field = PlayfieldLayout.letterbox(in: CGRect(x: 0, y: 0, width: 10, height: 4))
        XCTAssertEqual(field, CGRect(x: 5, y: 2, width: 0, height: 0))
    }
}
