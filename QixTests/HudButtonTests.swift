import CoreGraphics
import XCTest
@testable import Qix

final class HudButtonTests: XCTestCase {
    func testAColumnSmallerThanTheMinimumTargetGrowsToIt() {
        let minimum = HudButton.minimumTarget

        let size = HudButton.targetSize(CGSize(width: minimum / 2, height: minimum / 2))

        XCTAssertEqual(size, CGSize(width: minimum, height: minimum))
    }

    func testAColumnLargerThanTheMinimumTargetKeepsItsSize() {
        let column = CGSize(width: HudButton.minimumTarget * 2, height: HudButton.minimumTarget + 1)

        XCTAssertEqual(HudButton.targetSize(column), column)
    }

    func testOnlyTheShortSideGrows() {
        let minimum = HudButton.minimumTarget

        let size = HudButton.targetSize(CGSize(width: minimum * 2, height: minimum / 2))

        XCTAssertEqual(size, CGSize(width: minimum * 2, height: minimum))
    }
}
