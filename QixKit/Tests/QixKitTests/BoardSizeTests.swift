import XCTest
@testable import QixKit

final class BoardSizeTests: XCTestCase {
    func testTheStandardBoardIsQixCoresBoard() {
        XCTAssertEqual(BoardSize.standard, BoardSize(width: 160, height: 120))
    }

    func testTheStandardBoardIsFourByThree() {
        XCTAssertEqual(BoardSize.standard.aspectRatio, 4.0 / 3.0)
    }

    func testTheAspectRatioIsWidthOverHeight() {
        XCTAssertEqual(BoardSize(width: 30, height: 40).aspectRatio, 0.75)
    }
}
