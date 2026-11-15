import CoreGraphics
import XCTest
@testable import Qix

final class PauseButtonTests: XCTestCase {
    func testAColumnSmallerThanTheMinimumTargetGrowsToIt() {
        let minimum = PauseButton.minimumTarget

        let size = PauseButton.targetSize(CGSize(width: minimum / 2, height: minimum / 2))

        XCTAssertEqual(size, CGSize(width: minimum, height: minimum))
    }

    func testAColumnLargerThanTheMinimumTargetKeepsItsSize() {
        let column = CGSize(width: PauseButton.minimumTarget * 2, height: PauseButton.minimumTarget + 1)

        XCTAssertEqual(PauseButton.targetSize(column), column)
    }

    func testOnlyTheShortSideGrows() {
        let minimum = PauseButton.minimumTarget

        let size = PauseButton.targetSize(CGSize(width: minimum * 2, height: minimum / 2))

        XCTAssertEqual(size, CGSize(width: minimum * 2, height: minimum))
    }
}
